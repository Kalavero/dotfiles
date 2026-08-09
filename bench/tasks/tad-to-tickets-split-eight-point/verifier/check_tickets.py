#!/usr/bin/env python3
"""Score /app/tickets/*.json against the approved TAD for the
split-eight-point tad-to-tickets task.

The TAD deliberately contains one 8-point task (too big to ticket as-is) and
one legitimate 5-point task. Checks (weights):

  split          0.40  split enforcement, broken down as:
                       - no_eight        0.15  no ticket has estimate 8
                       - split_count     0.15  the 8-point task maps to >= 2
                                              tickets (via source_task)
                       - split_sizes     0.05  those tickets are each <= 5
                                              points and in scale
                       - kept_five       0.05  the 5-point task maps to
                                              exactly one ticket (estimate 5)
  mapping        0.15  every TAD task maps to >= 1 ticket; every non-8-point
                       task maps to exactly one
  estimates      0.15  all estimates within {0,1,2,3,5}; non-8-point tasks
                       carry the TAD's estimate over exactly
  dependencies   0.15  the ticket DAG realizes every edge in the TAD's
                       Sequencing section (a split task's tickets collectively
                       realize its edges) and adds no spurious cross-task edges
  self_contained 0.15  description >= 300 chars and references the TAD path

Extra tickets that match no TAD task deduct 0.05 each.

Writes the scalar reward to /logs/verifier/reward.txt and a per-check
breakdown to /logs/verifier/score.json.
"""

import json
import pathlib
import re
import shutil

APP = pathlib.Path("/app")
TAD_REL = "docs/tech-approaches/customer-notification-center.md"
TAD_PATH = APP / TAD_REL
TICKETS_DIR = APP / "tickets"
LOGS = pathlib.Path("/logs/verifier")

SCALE = {0, 1, 2, 3, 5}
MIN_DESC = 300

HEADING = re.compile(r"^###\s+Task\s+(\d+):\s*(.+?)\s*\((\d+)\s+points?\)\s*$", re.M)
DEP_LINE = re.compile(r"^-\s+Task\s+(\d+)\s+depends on\s+Tasks?\s+(.+?)\.?\s*$", re.M)


def parse_tad():
    text = TAD_PATH.read_text()
    tasks = {}
    for m in HEADING.finditer(text):
        tasks[int(m.group(1))] = {
            "title": m.group(2).strip(),
            "estimate": int(m.group(3)),
        }
    edges = []
    for m in DEP_LINE.finditer(text):
        dependent = int(m.group(1))
        for dep in re.findall(r"\d+", m.group(2)):
            edges.append((int(dep), dependent))
    return tasks, edges


def clean(title):
    s = re.sub(r"^task\s+\d+\s*:\s*", "", title.strip(), flags=re.I)
    s = re.sub(r"\s*\(\d+\s*points?\)\s*$", "", s, flags=re.I)
    return re.sub(r"\s+", " ", s).strip().lower()


def load_tickets():
    tickets, invalid = {}, []
    if not TICKETS_DIR.is_dir():
        return tickets, invalid
    for path in sorted(TICKETS_DIR.glob("*.json")):
        try:
            data = json.loads(path.read_text())
            if not isinstance(data, dict) or not all(
                k in data for k in ("title", "description", "estimate", "depends_on", "source_task")
            ):
                raise ValueError("missing required fields")
            tickets[path.name] = data
        except (ValueError, json.JSONDecodeError) as exc:
            invalid.append(f"{path.name}: {exc}")
    return tickets, invalid


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    tasks, tad_edges = parse_tad()
    tickets, invalid = load_tickets()

    breakdown = {"invalid_ticket_files": invalid, "tasks_found": len(tasks)}

    if not tickets:
        breakdown["fatal"] = "no valid ticket files under /app/tickets/"
        (LOGS / "score.json").write_text(json.dumps({"reward": 0.0, **breakdown}, indent=2))
        (LOGS / "reward.txt").write_text("0\n")
        print(json.dumps({"reward": 0.0, "fatal": breakdown["fatal"]}))
        return

    by_task = {num: [] for num in tasks}
    orphans = []
    for fname, t in tickets.items():
        st = clean(str(t["source_task"]))
        match = next((n for n, info in tasks.items() if clean(info["title"]) == st), None)
        if match is None:
            orphans.append(fname)
        else:
            by_task[match].append(fname)

    eight_tasks = [n for n, i in tasks.items() if i["estimate"] == 8]
    five_tasks = [n for n, i in tasks.items() if i["estimate"] == 5]

    # --- split enforcement (0.40 total) ---
    no_eight = 1.0 if all(t["estimate"] != 8 for t in tickets.values()) else 0.0
    split_count = (
        sum(1 for n in eight_tasks if len(by_task[n]) >= 2) / len(eight_tasks)
        if eight_tasks else 1.0
    )
    split_sizes = 1.0
    for n in eight_tasks:
        subs = by_task[n]
        if not subs or any(
            tickets[f]["estimate"] not in SCALE or tickets[f]["estimate"] > 5
            for f in subs
        ):
            split_sizes = 0.0
    kept_five = (
        sum(
            1
            for n in five_tasks
            if len(by_task[n]) == 1 and tickets[by_task[n][0]]["estimate"] == 5
        ) / len(five_tasks)
        if five_tasks else 1.0
    )
    split_score = (
        0.15 * no_eight + 0.15 * split_count + 0.05 * split_sizes + 0.05 * kept_five
    )

    # --- mapping (0.15): every task covered; non-8 tasks exactly once ---
    if tasks:
        covered = []
        for n in tasks:
            want = 2 if n in eight_tasks else 1
            covered.append(len(by_task[n]) >= want if n in eight_tasks else len(by_task[n]) == 1)
        mapping = sum(covered) / len(tasks)
    else:
        mapping = 0.0

    # --- estimates (0.15): in scale; non-8 tasks match the TAD exactly ---
    if tickets:
        in_scale = sum(1 for t in tickets.values() if t["estimate"] in SCALE) / len(tickets)
    else:
        in_scale = 0.0
    normal = [n for n in tasks if n not in eight_tasks and len(by_task[n]) == 1]
    if normal:
        carried = sum(
            1 for n in normal if tickets[by_task[n][0]]["estimate"] == tasks[n]["estimate"]
        ) / len(normal)
    else:
        carried = 0.0
    estimates = 0.5 * in_scale + 0.5 * carried

    # --- dependencies (0.15): TAD edges realized; no spurious cross-task edges ---
    task_of = {f: num for num, fns in by_task.items() for f in fns}
    realized = 0
    for dep, dependent in tad_edges:
        dep_files = set(by_task.get(dep, []))
        if any(
            dep_files & set(tickets[f].get("depends_on") or [])
            for f in by_task.get(dependent, [])
        ):
            realized += 1
    edge_recall = realized / len(tad_edges) if tad_edges else 1.0
    spurious = total_refs = 0
    for fname, t in tickets.items():
        for ref in t.get("depends_on") or []:
            total_refs += 1
            if ref not in tickets:
                spurious += 1
            elif task_of.get(ref) is not None and task_of.get(fname) is not None:
                a, b = task_of[ref], task_of[fname]
                if a != b and (a, b) not in tad_edges:
                    spurious += 1
    precision = 1.0 - (spurious / total_refs if total_refs else 0.0)
    dependencies = 0.6 * edge_recall + 0.4 * precision

    # --- self-containedness (0.15) ---
    sc_ok = sum(
        1
        for t in tickets.values()
        if len(str(t["description"])) >= MIN_DESC
        and (TAD_REL in str(t["description"]) or str(TAD_PATH) in str(t["description"]))
    )
    self_contained = sc_ok / len(tickets)

    reward = (
        split_score
        + 0.15 * mapping
        + 0.15 * estimates
        + 0.15 * dependencies
        + 0.15 * self_contained
        - 0.05 * len(orphans)
    )
    reward = max(0.0, min(1.0, reward))

    breakdown.update(
        {
            "reward": round(reward, 3),
            "split": {
                "score": round(split_score, 3),
                "no_eight": no_eight,
                "split_count": round(split_count, 3),
                "split_sizes": split_sizes,
                "kept_five": round(kept_five, 3),
                "eight_point_tasks": eight_tasks,
                "five_point_tasks": five_tasks,
            },
            "mapping": round(mapping, 3),
            "estimates": round(estimates, 3),
            "dependencies": {
                "score": round(dependencies, 3),
                "edges_realized": f"{realized}/{len(tad_edges)}",
                "spurious_refs": spurious,
            },
            "self_contained": round(self_contained, 3),
            "orphan_tickets": orphans,
        }
    )
    (LOGS / "score.json").write_text(json.dumps(breakdown, indent=2))
    (LOGS / "reward.txt").write_text(f"{round(reward, 3)}\n")

    if TICKETS_DIR.is_dir():
        dest = LOGS / "tickets"
        dest.mkdir(exist_ok=True)
        for path in TICKETS_DIR.glob("*.json"):
            shutil.copy(path, dest / path.name)
    print(json.dumps({"reward": round(reward, 3)}))


if __name__ == "__main__":
    main()
