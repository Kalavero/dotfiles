#!/bin/bash
# Oracle: derive the plan by reading /app/SPEC.md and the repository files,
# then write a fully compliant /app/PLAN.md. The next migration number is
# computed from migrations/, the exporter formats are read out of the spec,
# and every existing file named in files-touched is asserted to exist.
set -euo pipefail

python3 <<'PY'
import pathlib
import re
import sys

APP = pathlib.Path("/app")
spec = (APP / "SPEC.md").read_text()

# --- Derive what the spec actually asks for --------------------------------
FORMATS = [f for f in ("csv", "json", "markdown") if re.search(rf"\b{f}\b", spec, re.I)]
if len(FORMATS) != 3:
    sys.exit(f"expected 3 exporter formats in spec, found {FORMATS}")
for keyword in (r"\breports\b", r"\bmigration", r"independent", r"concurren"):
    if not re.search(keyword, spec, re.I):
        sys.exit(f"spec missing expected keyword: {keyword}")

# --- Inventory the repo -----------------------------------------------------
existing = {str(p.relative_to(APP)) for p in APP.rglob("*") if p.is_file()}


def exist(path):
    assert path in existing, f"expected fixture file missing: {path}"
    return path


def new(path):
    parent = pathlib.PurePosixPath(path).parent
    assert (APP / str(parent)).is_dir() or str(parent).startswith(
        ("app", "tests", "migrations")
    ), f"new file parent dir unexpected: {parent}"
    return path


# Next migration number comes from the migrations directory itself.
mig_dir = APP / "migrations"
numbers = [int(p.name.split("_")[0]) for p in mig_dir.glob("*.sql")]
next_mig = f"{max(numbers) + 1:04d}_reports.sql"

# --- Build the task list ----------------------------------------------------
# Task 1 is the shared foundation (blocking, sequential); the exporter
# slices and the history-surface slice are independent and parallelizable.
TASKS = [
    {
        "n": 1,
        "title": "Reports table migration and storage helpers (shared foundation)",
        "desc": f"Add `migrations/{next_mig}` creating the `reports` table "
        "(id, format, status, params, output_path, created_at, finished_at), "
        "extend the storage layer with run-recording helpers (insert run, "
        "update status/output_path, list runs), and scaffold the "
        "`app/exporters/` package.",
        "criteria": [
            "A fresh database gets a `reports` table with all spec'd columns via the migration runner",
            "Storage helpers can record a run, mark it done/failed with an output path, and list runs",
            "Existing migrations still apply cleanly on a fresh database",
        ],
        "verify": [
            "`python -m unittest tests.test_reports_storage` passes",
            "`python -m unittest discover -s tests` still passes (no regressions)",
            "Manual: init a scratch db and confirm `reports` appears in sqlite_master",
        ],
        "deps": "None",
        "parallel": "No — this task is BLOCKING and sequential. Every other "
        "task reads or writes the `reports` table it creates, so it must "
        "land and be reviewed before any other task starts.",
        "files": [
            (new(f"migrations/{next_mig}"), "new"),
            (exist("app/storage.py"), "modify"),
            (new("app/exporters/__init__.py"), "new"),
            (new("tests/test_reports_storage.py"), "new"),
        ],
    },
]

EXPORTER_TASKS = []
for offset, fmt in enumerate(FORMATS):
    module = f"app/exporters/{fmt}_exporter.py"
    test = f"tests/test_{fmt}_exporter.py"
    EXPORTER_TASKS.append(
        {
            "n": 2 + offset,
            "title": f"{fmt.upper() if fmt != 'markdown' else 'Markdown'} exporter slice",
            "desc": f"Add `{module}` (takes a Storage and an output "
            "directory, writes the {fmt} export, returns the path), wire "
            f"`report run --format {fmt}` into the CLI, and register the "
            "format in the `POST /reports` endpoint.",
            "criteria": [
                f"`report run --format {fmt}` writes a file under `exports/` and records a `done` run with its path",
                f"The exported {fmt} file contains all users and projects",
                "A failed export records a `failed` run",
            ],
            "verify": [
                f"`python -m unittest {test[:-3].replace('/', '.')}` passes",
                f"Manual: `python -m app.cli --db /tmp/r.sqlite3 report run --format {fmt}` then `report show 1` shows the output path",
            ],
            "deps": "Task 1",
            "parallel": "Yes — independent of the other exporter slices; "
            "may proceed concurrently once Task 1 lands. Only shared-file "
            "edits (app/api.py, app/cli.py) need light coordination.",
            "files": [
                (new(module), "new"),
                (exist("app/api.py"), "modify"),
                (exist("app/cli.py"), "modify"),
                (new(test), "new"),
            ],
        }
    )
TASKS += EXPORTER_TASKS

TASKS.append(
    {
        "n": 5,
        "title": "Report run history surface",
        "desc": "Expose run history: `GET /reports` and `GET /reports/{id}` "
        "endpoints plus the `report list` and `report show` CLI commands, "
        "backed by the storage helpers from Task 1.",
        "criteria": [
            "`GET /reports` lists runs newest first with id, format, status, and timestamps",
            "`GET /reports/{id}` returns one run including its output path",
            "`report list` and `report show ID` print the same information",
        ],
        "verify": [
            "`python -m unittest tests.test_reports_api` passes",
            "Manual: run an export, then compare `report list` output with `GET /reports`",
        ],
        "deps": "Task 1",
        "parallel": "Yes — independent of the exporter slices; may proceed "
        "concurrently once Task 1 lands.",
        "files": [
            (exist("app/api.py"), "modify"),
            (exist("app/cli.py"), "modify"),
            (new("tests/test_reports_api.py"), "new"),
        ],
    }
)

# --- Sanity-check the plan before writing -----------------------------------
assert len(TASKS) >= 4, "need at least 4 tasks"
for t in TASKS:
    assert 0 < len(t["files"]) <= 5, f"task {t['n']} file budget violated"
ids = {str(t["n"]) for t in TASKS}
for t in TASKS:
    for ref in re.findall(r"\d+", t["deps"]):
        assert ref in ids, f"task {t['n']} depends on undefined task {ref}"
parallel_ids = [str(t["n"]) for t in TASKS[1:]]
assert all(t["deps"] == "Task 1" for t in TASKS[1:])

# --- Emit PLAN.md -----------------------------------------------------------
out = ["# Implementation Plan: Report Exports", ""]
out.append("## Overview")
out.append("")
out.append(
    "Add database-tracked report exports in three formats (csv, json, "
    "markdown) to the projects app. One shared foundation task (the "
    "`reports` table migration plus storage helpers) must land first; the "
    "three exporter slices and the history surface are independent of one "
    "another and can proceed concurrently afterwards."
)
out.append("")
out.append("## Parallelization and Sequencing")
out.append("")
out.append(
    "- **Sequential / blocking:** Task 1 is not parallelizable. Every other "
    "task reads or writes the `reports` table and helpers it creates, so "
    "Task 1 must merge before any other task starts."
)
out.append(
    f"- **Parallelizable:** Tasks {', '.join(parallel_ids)} are independent "
    "of one another and may proceed concurrently once Task 1 lands. Each "
    "owns a disjoint new module and test file; the only shared files "
    "(`app/api.py`, `app/cli.py`) receive small additive edits, so merge "
    "conflicts are unlikely and easy to resolve."
)
out.append("")
out.append("## Task List")
out.append("")


def emit_task(t):
    lines = [f"## Task {t['n']}: {t['title']}", ""]
    lines.append(f"**Description:** {t['desc']}")
    lines.append("")
    lines.append("**Acceptance criteria:**")
    lines += [f"- [ ] {c}" for c in t["criteria"]]
    lines.append("")
    lines.append("**Verification:**")
    lines += [f"- [ ] {v}" for v in t["verify"]]
    lines.append("")
    lines.append(f"**Dependencies:** {t['deps']}")
    lines.append("")
    lines.append(f"**Parallelizable:** {t['parallel']}")
    lines.append("")
    lines.append("**Files touched:**")
    lines += [f"- `{path}` ({kind})" for path, kind in t["files"]]
    lines.append("")
    n = len(t["files"])
    size = "Small" if n <= 2 else "Medium"
    lines.append(f"**Estimated scope:** {size} ({n} files)")
    return lines


def emit_checkpoint(title, items):
    lines = [f"## Checkpoint: {title}"]
    lines += [f"- [ ] {i}" for i in items]
    lines.append("")
    return lines


out += emit_task(TASKS[0])
out.append("")
out += emit_checkpoint(
    "after Task 1 (foundation merged — parallel work may begin)",
    [
        "`python -m unittest discover -s tests` passes on a fresh database",
        "Migration and storage helpers reviewed and merged",
        "Tasks 2-5 are assigned to separate engineers and start concurrently",
    ],
)
for t in TASKS[1:]:
    out += emit_task(t)
    out.append("")
out += emit_checkpoint(
    "after Tasks 2-5 (complete)",
    [
        "`python -m unittest discover -s tests` passes",
        "All three export formats run end-to-end via API and CLI",
        "Run history is visible through both interfaces",
        "Ready for human review",
    ],
)
out.append("## Risks and Mitigations")
out.append("")
out.append("| Risk | Impact | Mitigation |")
out.append("|------|--------|------------|")
out.append("| Parallel edits to app/api.py and app/cli.py collide | Low | Keep each slice's edits additive; rebase on the merged Task 1 |")
out.append("| Migration applied against a live database | Med | Apply on a fresh copy first; the migration runner records applied names |")

(APP / "PLAN.md").write_text("\n".join(out) + "\n")
print(f"wrote /app/PLAN.md with {len(TASKS)} tasks and 2 checkpoints")
PY
