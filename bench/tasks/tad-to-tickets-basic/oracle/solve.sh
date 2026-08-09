#!/bin/bash
# Oracle: parse the approved TAD and emit one JSON ticket per proposed task.
# The TAD's Sequencing section is prose, not a dependency list: the oracle
# asserts the prose cues it relies on are present, then applies the edge set
# those cues encode. Tasks the TAD leaves un-estimated are sized from their
# described work on the relative-points scale; tasks the TAD estimates carry
# that value over. Nothing is hardcoded that is not first parsed or asserted
# from the TAD.
set -euo pipefail

python3 <<'PY'
import json
import pathlib
import re

TAD_REL = "docs/tech-approaches/scheduled-report-exports.md"
TAD = pathlib.Path("/app") / TAD_REL
OUT = pathlib.Path("/app/tickets")
OUT.mkdir(parents=True, exist_ok=True)

text = TAD.read_text()

HEADING = re.compile(
    r"^###\s+Task\s+(\d+):\s*(.+?)\s*(?:\((\d+)\s+points?\))?\s*$", re.M
)

headings = list(HEADING.finditer(text))
tasks = {}
for i, m in enumerate(headings):
    num = int(m.group(1))
    end = headings[i + 1].start() if i + 1 < len(headings) else len(text)
    body = text[m.end():end].strip()
    body = re.split(r"^##\s", body, flags=re.M)[0].strip()
    tasks[num] = {
        "title": m.group(2).strip(),
        "estimate": int(m.group(3)) if m.group(3) else None,
        "body": body,
    }

# The Sequencing section is prose. Assert the cues the edge set is read
# from, so a differently-worded TAD fails loudly instead of silently
# producing wrong tickets.
seq = text.split("## Sequencing", 1)[1]
seq = re.split(r"^##\s", seq, flags=re.M)[0]
for cue in (
    "neither can start before",
    "can only start once the migration is in",
    "additionally needs the generation job",
    "goes last",
    "creatable through the endpoints",
    "email path needs to be live",
    "independent of all of this",
):
    assert re.search(cue.replace(" ", r"\s+"), seq), f"missing sequencing cue: {cue!r}"

# Edges (dependency, dependent) read from the asserted prose:
#   "neither [endpoints nor generation job] can start before the migration"
#       -> (1,2), (1,3)
#   "email delivery additionally needs the generation job"
#       -> (3,4)
#   "schedules have to be creatable through the endpoints ... and the email
#    path needs to be live before the scheduler enqueues real customer work"
#       -> (2,5), (4,5)
# Task 6 is "independent of all of this" -> no edges.
EDGES = [(1, 2), (1, 3), (3, 4), (2, 5), (4, 5)]
deps = {num: [] for num in tasks}
for dep, dependent in EDGES:
    assert dep in tasks and dependent in tasks, "edge references unknown task"
    deps[dependent].append(dep)

# Sanity: the TAD must actually leave tasks 3, 5, 6 un-estimated and give
# estimates for the rest.
assert [n for n, t in tasks.items() if t["estimate"] is None] == [3, 5, 6]

# Estimates derived from the described work for the un-estimated tasks, on
# the relative-points scale {0,1,2,3,5}:
#   Task 3 — background job with render+upload+signed URLs, idempotency,
#            and retry/alerting semantics: multi-layer work -> 3.
#   Task 5 — scheduler with catch-up, jitter, and runbook: some unknowns
#            in the operational edge cases -> 3.
#   Task 6 — one label string plus one snapshot test: exactly known -> 1.
DERIVED = {
    "implement the export generation job": 3,
    "wire the weekly scheduler with missed-day catch-up": 3,
    "rename the reports-page export button": 1,
}
for num, t in tasks.items():
    if t["estimate"] is None:
        key = t["title"].lower()
        assert key in DERIVED, f"no derived estimate for un-estimated task {num}"
        t["estimate"] = DERIVED[key]


def slug(title):
    s = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    return re.sub(r"-{2,}", "-", s)


filenames = {num: f"{slug(t['title'])}.json" for num, t in tasks.items()}

for num, t in tasks.items():
    description = (
        f"{t['body']}\n\n"
        f"This ticket implements task {num} (\"{t['title']}\") of the approved "
        f"technical approach document at `{TAD_REL}`. Read that document "
        "before starting: its Approach section explains the design this task "
        "is part of, and its Sequencing section explains how it fits with the "
        "other tickets. The work is done when the behavior described above is "
        "implemented, covered by tests, and matches the TAD's approach."
    )
    ticket = {
        "title": t["title"],
        "description": description,
        "estimate": t["estimate"],
        "depends_on": [filenames[d] for d in sorted(deps.get(num, []))],
        "source_task": t["title"],
    }
    (OUT / filenames[num]).write_text(json.dumps(ticket, indent=2) + "\n")

print(f"wrote {len(tasks)} tickets to {OUT}")
PY
