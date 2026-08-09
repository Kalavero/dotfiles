#!/usr/bin/env python3
"""Score /app/tickets/*.json against the approved TAD for the basic
tad-to-tickets task.

The TAD expresses its build order in prose (no dependency list) and leaves
three of its six tasks without point estimates, so faithful copying is not
enough: the agent must interpret the sequencing prose into depends_on edges
and size the un-estimated tasks on a relative-points scale itself.

Checks (weights):
  mapping        0.30  every TAD task mapped to exactly one ticket via
                       source_task
  estimates      0.20  every estimate within {0,1,2,3,5}; tasks the TAD
                       estimates must carry that value over exactly, and
                       tasks the TAD leaves un-estimated must fall within
                       the expected range below (reasonableness bounds)
  dependencies   0.25  ticket DAG vs. the edge set expressed by the TAD's
                       prose Sequencing section (truth set below): every
                       real edge realized, no spurious cross-task edges
  self_contained 0.15  description >= 300 chars and references the TAD path
  no_eight       0.10  no ticket carries an estimate of 8

Extra tickets that match no TAD task (or duplicate a task) deduct 0.05 each.

Writes the scalar reward to /logs/verifier/reward.txt and a per-check
breakdown to /logs/verifier/score.json.
"""

import json
import pathlib
import re
import shutil

APP = pathlib.Path("/app")
TAD_REL = "docs/tech-approaches/scheduled-report-exports.md"
TAD_PATH = APP / TAD_REL
TICKETS_DIR = APP / "tickets"
LOGS = pathlib.Path("/logs/verifier")

SCALE = {0, 1, 2, 3, 5}
MIN_DESC = 300

# Truth expressed by the TAD's prose Sequencing section (dep, dependent):
# "the CRUD endpoints and the export generation job ... neither can start
#  before the migration lands"            -> (1,2), (1,3)
# "email delivery additionally needs the generation job" -> (3,4)
# "schedules have to be creatable through the endpoints before there is
#  anything to run, and the email path needs to be live before the
#  scheduler enqueues real customer work"  -> (2,5), (4,5)
# Task 6 ("independent of all of this") has no edges.
EXPECTED_EDGES = {(1, 2), (1, 3), (3, 4), (2, 5), (4, 5)}

# Reasonableness bounds (inclusive) for tasks the TAD leaves un-estimated.
# Task 3 (background job: render + upload + signed URLs + idempotency +
# retry/alerting semantics) is at least a 3, plausibly a 5.
# Task 5 (scheduler with catch-up, jitter, runbook) is at least a 3.
# Task 6 (button copy rename + one snapshot test) is at most a 1.
EXPECTED_RANGES = {3: (3, 5), 5: (3, 5), 6: (0, 1)}

HEADING = re.compile(
    r"^###\s+Task\s+(\d+):\s*(.+?)\s*(?:\((\d+)\s+points?\))?\s*$", re.M
)


def parse_tad():
    """Return tasks mapping task number -> {title, estimate|None}."""
    text = TAD_PATH.read_text()
    tasks = {}
    for m in HEADING.finditer(text):
        tasks[int(m.group(1))] = {
            "title": m.group(2).strip(),
            "estimate": int(m.group(3)) if m.group(3) else None,
        }
    return tasks


def clean(title):
    """Normalize a task title, tolerating a 'Task N:' prefix or a trailing
    '(N points)' suffix in the ticket's source_task."""
    s = re.sub(r"^task\s+\d+\s*:\s*", "", title.strip(), flags=re.I)
    s = re.sub(r"\s*\(\d+\s*points?\)\s*$", "", s, flags=re.I)
    return re.sub(r"\s+", " ", s).strip().lower()


def load_tickets():
    """Return (tickets, invalid): tickets maps filename -> parsed dict."""
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


def estimate_ok(est, task):
    """In scale, and either equal to the TAD's estimate or within the
    expected range for a task the TAD leaves un-estimated."""
    if not isinstance(est, int) or est not in SCALE:
        return False
    if task["estimate"] is not None:
        return est == task["estimate"]
    lo, hi = EXPECTED_RANGES.get(task["num"], (min(SCALE), max(SCALE)))
    return lo <= est <= hi


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    tasks = parse_tad()
    for num, t in tasks.items():
        t["num"] = num
    tickets, invalid = load_tickets()

    breakdown = {"invalid_ticket_files": invalid, "tasks_found": len(tasks)}

    if not tickets:
        breakdown["fatal"] = "no valid ticket files under /app/tickets/"
        (LOGS / "score.json").write_text(json.dumps({"reward": 0.0, **breakdown}, indent=2))
        (LOGS / "reward.txt").write_text("0\n")
        print(json.dumps({"reward": 0.0, "fatal": breakdown["fatal"]}))
        return

    # Map each TAD task number to the ticket filenames claiming it.
    by_task = {num: [] for num in tasks}
    orphans = []
    for fname, t in tickets.items():
        st = clean(str(t["source_task"]))
        match = next((n for n, info in tasks.items() if clean(info["title"]) == st), None)
        if match is None:
            orphans.append(fname)
        else:
            by_task[match].append(fname)
    extras = orphans + [f for fns in by_task.values() for f in fns[1:]]

    # (a) mapping: every task mapped to exactly one ticket.
    mapped_once = sum(1 for fns in by_task.values() if len(fns) == 1)
    mapping = mapped_once / len(tasks) if tasks else 0.0

    # (b) estimates: in scale; carried over exactly where the TAD gives one,
    # within the expected range where it doesn't.
    mapped_pairs = [
        (fname, num) for num, fns in by_task.items() for fname in fns[:1]
    ]
    if mapped_pairs:
        ok = sum(
            1 for fname, num in mapped_pairs
            if estimate_ok(tickets[fname]["estimate"], tasks[num])
        )
        estimates = ok / len(mapped_pairs)
    else:
        estimates = 0.0

    # (c) dependencies: every prose-truth edge realized, no spurious
    # cross-task edges.
    task_of = {f: num for num, fns in by_task.items() for f in fns}
    realized = 0
    for dep, dependent in EXPECTED_EDGES:
        dep_files = set(by_task.get(dep, []))
        if any(
            dep_files & set(tickets[f].get("depends_on") or [])
            for f in by_task.get(dependent, [])
        ):
            realized += 1
    edge_recall = realized / len(EXPECTED_EDGES) if EXPECTED_EDGES else 1.0
    spurious = total_refs = 0
    for fname, t in tickets.items():
        for ref in t.get("depends_on") or []:
            total_refs += 1
            if ref not in tickets:
                spurious += 1
            elif task_of.get(ref) is not None and task_of.get(fname) is not None:
                a, b = task_of[ref], task_of[fname]
                if a != b and (a, b) not in EXPECTED_EDGES:
                    spurious += 1
    precision = 1.0 - (spurious / total_refs if total_refs else 0.0)
    dependencies = 0.6 * edge_recall + 0.4 * precision

    # (d) self-containedness: length + TAD reference.
    sc_ok = sum(
        1
        for t in tickets.values()
        if len(str(t["description"])) >= MIN_DESC
        and (TAD_REL in str(t["description"]) or str(TAD_PATH) in str(t["description"]))
    )
    self_contained = sc_ok / len(tickets)

    # (e) no estimate of 8 anywhere.
    no_eight = 1.0 if all(t["estimate"] != 8 for t in tickets.values()) else 0.0

    reward = (
        0.30 * mapping
        + 0.20 * estimates
        + 0.25 * dependencies
        + 0.15 * self_contained
        + 0.10 * no_eight
        - 0.05 * len(extras)
    )
    reward = max(0.0, min(1.0, reward))

    breakdown.update(
        {
            "reward": round(reward, 3),
            "mapping": round(mapping, 3),
            "estimates": {
                "score": round(estimates, 3),
                "per_task": {
                    str(num): {
                        "tad_estimate": tasks[num]["estimate"],
                        "expected_range": list(EXPECTED_RANGES[num])
                        if tasks[num]["estimate"] is None and num in EXPECTED_RANGES
                        else None,
                        "ticket_estimate": tickets[fns[0]]["estimate"] if fns else None,
                    }
                    for num, fns in sorted(by_task.items())
                },
            },
            "dependencies": {
                "score": round(dependencies, 3),
                "edges_realized": f"{realized}/{len(EXPECTED_EDGES)}",
                "spurious_refs": spurious,
            },
            "self_contained": round(self_contained, 3),
            "no_eight": no_eight,
            "extra_tickets": extras,
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
