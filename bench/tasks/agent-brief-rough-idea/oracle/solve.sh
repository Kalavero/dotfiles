#!/bin/bash
# Oracle: explore the repo (README, IDEA.md, modules, tests), verify every
# path the brief cites actually exists, pull the real test command from the
# README, and write an agent-ready brief to /app/tasks/.
set -euo pipefail

python3 <<'PY'
import pathlib
import re
import sys

APP = pathlib.Path("/app")
TASKS = APP / "tasks"
TASKS.mkdir(parents=True, exist_ok=True)

idea = (APP / "IDEA.md").read_text()
readme = (APP / "README.md").read_text()

# Discover the repo's real test command from the README rather than guessing.
test_cmd = None
for line in readme.splitlines():
    if "pytest" in line:
        test_cmd = "python -m pytest"
        break
assert test_cmd, "could not discover the test command from README.md"

# Every existing path the brief will cite, verified before writing.
CITED = [
    "IDEA.md",
    "exportly/db.py",
    "exportly/csv_export.py",
    "exportly/cli.py",
    "tests/test_csv_export.py",
    "tests/test_cli.py",
    "pyproject.toml",
]
for rel in CITED:
    assert (APP / rel).exists(), f"cited path missing: {rel}"

brief = f"""# Brief: Cache monthly usage aggregates so repeat exports are fast

## Objective
Make repeat CSV exports of the same account/month fast by caching the
computed monthly aggregates, while keeping the exported CSV bytes exactly as
billing's importer expects them.

## Context
- Rough idea being formalized: `IDEA.md` — users (especially billing)
  re-export the same accounts every month and each run recomputes everything.
- Relevant code: `exportly/db.py` — `monthly_totals()` rescans every usage
  row for the month on each export; this is the slow path.
- Relevant code: `exportly/csv_export.py` — writes the CSV; its column order
  and formatting are contractual for billing's invoicing import.
- Relevant code: `exportly/cli.py` — the `export` command wiring the store to
  the CSV writer; the natural seam for reading/writing the cache.
- Follow the pattern in: `tests/test_csv_export.py` — golden-file style
  assertions on exact CSV output; the cache change must keep these passing.
- Reuse: the existing sqlite storage in `exportly/db.py` for the cache rather
  than introducing a new storage dependency; a new `exportly/cache.py` module
  is the proposed home for the cache logic.

## Constraints
- The CSV bytes for a given account/month must be identical before and after
  the change — same columns, same order, same formatting (billing imports
  this file; see `exportly/csv_export.py` and the warning in `README.md`).
- No new third-party dependencies; the project is stdlib-only today (see
  `pyproject.toml`).
- CLI flags, output messages, and exit codes stay unchanged.
- Stale data must never be served: if underlying usage rows for an
  account/month change, the next export reflects the change.

## Acceptance criteria
- [ ] A second export of the same account/month is served from the cache
  instead of rescanning usage rows (prove it with a test that counts queries
  or rows read).
- [ ] `tests/test_csv_export.py` and `tests/test_cli.py` pass unmodified,
  proving the CSV format is unchanged.
- [ ] A test demonstrates that inserting a new usage row invalidates or
  bypasses the cached aggregate for that account/month.
- [ ] A test demonstrates correct behavior when the cache is empty or absent
  (cold start produces byte-identical CSV to the uncached path).
- [ ] The full test suite passes via the command in Verification.

## Non-goals
- Do not change the CSV columns, ordering, quoting, or file layout in any
  way — billing's importer depends on the current byte format.
- Do not build cache administration tooling: no TTL configuration, no cache
  stats, no CLI flags for cache management.
- Do not cache anything beyond per-account/month aggregates (no partial-month
  or cross-account rollups).

## Verification
- Run: `{test_cmd}`
- Manual check: export the same account/month twice with
  `python -m exportly export` and diff the two CSVs — they must be identical,
  and the second run should complete without rescanning the usage rows.
"""

out = TASKS / "brief-cache-monthly-aggregates.md"
out.write_text(brief)
print(f"wrote {out} (test command discovered: {test_cmd!r})", file=sys.stderr)
PY
