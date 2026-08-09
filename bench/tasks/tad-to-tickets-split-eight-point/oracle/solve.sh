#!/bin/bash
# Oracle: parse the approved TAD and emit tickets. Tasks estimated 8 points
# are too big to ticket as-is, so the oracle splits them into coherent
# smaller tickets (each <= 5 points, with the split reason stated in the
# description) before writing anything. Everything else carries the TAD's
# estimate over directly. Sequencing edges are encoded as depends_on file
# references: edges into a split task land on its first sub-ticket, edges out
# of a split task leave from its last sub-ticket.
set -euo pipefail

python3 <<'PY'
import json
import pathlib
import re

TAD_REL = "docs/tech-approaches/customer-notification-center.md"
TAD = pathlib.Path("/app") / TAD_REL
OUT = pathlib.Path("/app/tickets")
OUT.mkdir(parents=True, exist_ok=True)

text = TAD.read_text()

HEADING = re.compile(r"^###\s+Task\s+(\d+):\s*(.+?)\s*\((\d+)\s+points?\)\s*$", re.M)
DEP_LINE = re.compile(r"^-\s+Task\s+(\d+)\s+depends on\s+Tasks?\s+(.+?)\.?\s*$", re.M)

headings = list(HEADING.finditer(text))
tasks = {}
for i, m in enumerate(headings):
    num = int(m.group(1))
    end = headings[i + 1].start() if i + 1 < len(headings) else len(text)
    body = text[m.end():end].strip()
    body = re.split(r"^##\s", body, flags=re.M)[0].strip()
    tasks[num] = {
        "title": m.group(2).strip(),
        "estimate": int(m.group(3)),
        "body": body,
    }

tad_deps = {num: [] for num in tasks}
for m in DEP_LINE.finditer(text):
    dependent = int(m.group(1))
    tad_deps.setdefault(dependent, []).extend(
        int(d) for d in re.findall(r"\d+", m.group(2))
    )


def slug(title):
    s = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    return re.sub(r"-{2,}", "-", s)


# A task estimated at 8 points is too large to become a ticket as-is; split
# it into coherent stages along the work's natural seams. Keyed by the
# parsed TAD task title so nothing here fires unless the TAD actually
# contains that 8-point task.
SPLIT_PLANS = {
    "build the notification pipeline": [
        (
            "Notification pipeline: event ingestion and persistence",
            3,
            "Consume domain events from the bus and persist a notification "
            "record per affected user, keyed by an idempotency key so "
            "re-delivered events never create duplicates. Measure and log "
            "peak event-volume shape while building this — it is one of the "
            "critical unknowns called out in the TAD.",
        ),
        (
            "Notification pipeline: template rendering",
            2,
            "Render notification subject/body from per-kind templates, fed "
            "from the persisted event payload. Benchmark rendering with "
            "large payloads — the second unknown flagged in the TAD — and "
            "note the results in the ticket before closing.",
        ),
        (
            "Notification pipeline: channel delivery with retries",
            3,
            "Deliver rendered notifications: write the in-app record, and "
            "send email when the user's preferences enable it, with "
            "exponential-backoff retries and dead-lettering. Delivery reads "
            "preferences through the NotificationKind registry so channels "
            "stay consistent with the preferences API.",
        ),
    ]
}

# Build the ticket list: one ticket per normal task, several per 8-point task.
# tickets[num] is the ordered list of ticket dicts for TAD task num.
tickets = {}
for num, t in tasks.items():
    plan = SPLIT_PLANS.get(t["title"].lower()) if t["estimate"] == 8 else None
    if plan:
        subtickets = []
        for sub_title, est, sub_body in plan:
            description = (
                f"{sub_body}\n\n"
                f"This ticket is one part of TAD task {num} (\"{t['title']}\"), "
                f"which the TAD estimates at 8 points. An 8-point task is too "
                f"large to ticket responsibly, so it was split into smaller, "
                f"separately deliverable tickets before ticketing; this is one "
                f"of {len(plan)} parts. Original task context from the TAD: "
                f"{t['body']}\n\n"
                f"Source: approved technical approach document at `{TAD_REL}` — "
                "read its Approach and Sequencing sections before starting."
            )
            subtickets.append(
                {"title": sub_title, "estimate": est, "description": description,
                 "source_task": t["title"]}
            )
        tickets[num] = subtickets
    else:
        description = (
            f"{t['body']}\n\n"
            f"This ticket implements task {num} (\"{t['title']}\") of the "
            f"approved technical approach document at `{TAD_REL}`. Read that "
            "document before starting: its Approach section explains the "
            "design this task is part of, and its Sequencing section explains "
            "how it fits with the other tickets. The work is done when the "
            "behavior described above is implemented, covered by tests, and "
            "matches the TAD's approach."
        )
        tickets[num] = [
            {"title": t["title"], "estimate": t["estimate"],
             "description": description, "source_task": t["title"]}
        ]

# Assign filenames.
for num, subs in tickets.items():
    for sub in subs:
        sub["fname"] = f"{slug(sub['title'])}.json"

# Wire dependencies. Chain split sub-tickets in order; TAD edges into a task
# land on its first sub-ticket; TAD edges out leave from its last sub-ticket.
for num, subs in tickets.items():
    for i, sub in enumerate(subs):
        deps = []
        if i > 0:
            deps.append(subs[i - 1]["fname"])
        else:
            for d in sorted(set(tad_deps.get(num, []))):
                deps.append(tickets[d][-1]["fname"])
        sub["depends_on"] = deps

for num, subs in tickets.items():
    for sub in subs:
        ticket = {
            "title": sub["title"],
            "description": sub["description"],
            "estimate": sub["estimate"],
            "depends_on": sub["depends_on"],
            "source_task": sub["source_task"],
        }
        (OUT / sub["fname"]).write_text(json.dumps(ticket, indent=2) + "\n")

total = sum(len(s) for s in tickets.values())
print(f"wrote {total} tickets for {len(tasks)} TAD tasks to {OUT}")
PY
