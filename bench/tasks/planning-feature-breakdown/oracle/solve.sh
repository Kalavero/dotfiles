#!/bin/bash
# Oracle: derive the plan by reading /app/SPEC.md and the repository files,
# then write a fully compliant /app/PLAN.md. Existing files referenced in
# files-touched are asserted to exist; new files are asserted to live under
# existing directories. Nothing is planned that the spec does not ask for.
set -euo pipefail

python3 <<'PY'
import pathlib
import re
import sys

APP = pathlib.Path("/app")
spec = (APP / "SPEC.md").read_text()

# --- Derive what the spec actually asks for --------------------------------
REQUIRED_KEYWORDS = {
    "workspaces": r"\bworkspace\b",
    "roles": r"\brole\b",
    "invites": r"\binvite\b",
    "audit": r"\baudit\b",
    "cli": r"\bcli\b|\bcommand",
}
missing = [k for k, pat in REQUIRED_KEYWORDS.items() if not re.search(pat, spec, re.I)]
if missing:
    sys.exit(f"spec does not mention expected feature parts: {missing}")

# --- Inventory the repo; every existing file we name must be real ----------
existing = {str(p.relative_to(APP)) for p in APP.rglob("*") if p.is_file()}


def exist(path):
    assert path in existing, f"expected fixture file missing: {path}"
    return path


def new(path):
    parent = str(pathlib.PurePosixPath(path).parent)
    assert (
        APP / parent
    ).is_dir(), f"new file parent dir does not exist: {parent}"
    return path


# --- Build the task list ----------------------------------------------------
# Vertical slices ordered by dependency: each slice carries its model,
# storage, interface, and test changes together.
TASKS = [
    {
        "n": 1,
        "title": "Workspace creation slice",
        "desc": "Add the `Workspace` dataclass to the models, a `workspaces` "
        "collection to the storage layer, the `POST /workspaces` and "
        "`GET /workspaces` endpoints, the `workspace create` / "
        "`workspace list` CLI commands, and tests for the whole path.",
        "criteria": [
            "A workspace can be created with a name and generated URL-safe slug via both the API and the CLI",
            "The creating user is stored as the workspace owner",
            "Workspaces can be listed through both interfaces",
        ],
        "verify": [
            "`python -m unittest tests.test_workspaces` passes",
            "Manual: `python -m app.cli --db /tmp/ws.json workspace create \"Engineering\" 1` prints a workspace with a slug",
            "`python -m unittest discover -s tests` still passes (no regressions)",
        ],
        "deps": "None",
        "files": [
            (exist("app/models.py"), "modify"),
            (exist("app/storage.py"), "modify"),
            (exist("app/api.py"), "modify"),
            (exist("app/cli.py"), "modify"),
            (new("tests/test_workspaces.py"), "new"),
        ],
    },
    {
        "n": 2,
        "title": "Membership and roles slice",
        "desc": "Extend the models and storage with workspace memberships "
        "carrying `owner`/`admin`/`member` roles, expose member add/remove/"
        "role-change under `/workspaces/{id}/members`, and enforce that a "
        "workspace always keeps at least one owner.",
        "criteria": [
            "Members can be added, removed, and re-roled via the API",
            "Removing or demoting the last owner is rejected",
            "Only `owner`/`admin` members can manage membership",
        ],
        "verify": [
            "`python -m unittest tests.test_workspaces` passes, including the last-owner guard cases",
            "Manual: demote the only owner via the API and confirm a 400 response",
        ],
        "deps": "Task 1",
        "files": [
            (exist("app/models.py"), "modify"),
            (exist("app/storage.py"), "modify"),
            (exist("app/api.py"), "modify"),
            (new("tests/test_membership.py"), "new"),
        ],
    },
    {
        "n": 3,
        "title": "Invite flow slice",
        "desc": "Add invites: create-by-email with a unique token and 7-day "
        "expiry, accept/decline by token (accepting creates a `member` "
        "membership), pending-invite listing, and the `workspace invite` / "
        "`accept` / `decline` CLI commands.",
        "criteria": [
            "Owners/admins can invite an email; the invite has a unique token and an expiry 7 days out",
            "Accepting an invite creates a membership with the `member` role; declining marks it declined",
            "Expired or already-answered invites cannot be accepted",
            "Pending invites can be listed per workspace",
        ],
        "verify": [
            "`python -m unittest tests.test_invites` passes",
            "Manual: invite, accept with the printed token, and confirm the member appears in `workspace members`",
        ],
        "deps": "Task 2 (needs membership creation and role checks)",
        "files": [
            (exist("app/models.py"), "modify"),
            (exist("app/storage.py"), "modify"),
            (exist("app/api.py"), "modify"),
            (exist("app/cli.py"), "modify"),
            (new("tests/test_invites.py"), "new"),
        ],
    },
    {
        "n": 4,
        "title": "Audit log slice",
        "desc": "Record every workspace event (created, member added/removed,"
        " role changed, invite sent/accepted/declined) as an audit entry "
        "with timestamp, actor, action, and target, and expose the log "
        "newest-first at `/workspaces/{id}/audit`.",
        "criteria": [
            "Every event listed in SPEC.md section 3 produces an audit entry with actor, action, and target",
            "`GET /workspaces/{id}/audit` returns entries newest first",
        ],
        "verify": [
            "`python -m unittest tests.test_audit` passes",
            "Manual: create a workspace, add a member, then read the audit endpoint and confirm both events in order",
        ],
        "deps": "Task 1; hooks into events from Tasks 2 and 3 as they land",
        "files": [
            (exist("app/models.py"), "modify"),
            (exist("app/storage.py"), "modify"),
            (exist("app/api.py"), "modify"),
            (new("tests/test_audit.py"), "new"),
        ],
    },
    {
        "n": 5,
        "title": "Workspace management CLI completion",
        "desc": "Finish the CLI surface: `workspace members`, "
        "`workspace audit`, and member management commands, wiring them to "
        "the API/storage behavior built above.",
        "criteria": [
            "`workspace members` lists members with roles",
            "`workspace audit` prints the audit log newest first",
            "Member add/remove/role-change are reachable from the CLI",
        ],
        "verify": [
            "`python -m unittest tests.test_cli` passes",
            "Manual: run each `workspace` subcommand against a scratch db and compare with the API output",
        ],
        "deps": "Task 2, Task 4",
        "files": [
            (exist("app/cli.py"), "modify"),
            (exist("app/api.py"), "modify"),
            (exist("tests/test_cli.py"), "modify"),
        ],
    },
]

# --- Sanity-check the plan against the budget rules before writing ---------
assert len(TASKS) >= 4, "need at least 4 tasks"
for t in TASKS:
    assert 0 < len(t["files"]) <= 5, f"task {t['n']} file budget violated"
ids = {str(t["n"]) for t in TASKS}
for t in TASKS:
    for ref in re.findall(r"\d+", t["deps"]):
        assert ref in ids, f"task {t['n']} depends on undefined task {ref}"

# --- Emit PLAN.md -----------------------------------------------------------
out = ["# Implementation Plan: Team Workspaces", ""]
out.append("## Overview")
out.append("")
out.append(
    "Add team workspaces (membership with roles, token-based invites, and an "
    "audit log) to the projects app, reachable from both the HTTP API and the "
    "CLI. Each task is a vertical slice that carries its model, storage, "
    "interface, and test changes together; tasks are ordered so nothing is "
    "built before the work it relies on."
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
    "after Task 1 (foundation)",
    [
        "`python -m unittest discover -s tests` passes",
        "Workspace can be created end-to-end via API and CLI",
        "Review with a human before building on the workspace model",
    ],
)
out += emit_task(TASKS[1])
out.append("")
out += emit_task(TASKS[2])
out.append("")
out += emit_checkpoint(
    "after Tasks 2-3 (membership and invites)",
    [
        "All tests pass, including last-owner guard and invite expiry cases",
        "Invite -> accept -> member-visible flow works end-to-end",
    ],
)
out += emit_task(TASKS[3])
out.append("")
out += emit_task(TASKS[4])
out.append("")
out += emit_checkpoint(
    "after Tasks 4-5 (complete)",
    [
        "`python -m unittest discover -s tests` passes",
        "Every acceptance criterion in SPEC.md sections 1-4 is met",
        "Existing user/project behavior unchanged",
        "Ready for human review",
    ],
)
out.append("## Risks and Mitigations")
out.append("")
out.append("| Risk | Impact | Mitigation |")
out.append("|------|--------|------------|")
out.append("| Role checks scattered across API and CLI | Med | Keep enforcement in the membership logic, not the interfaces |")
out.append("| JSON storage write contention | Low | Single-process app; reuse the existing storage lock |")

(APP / "PLAN.md").write_text("\n".join(out) + "\n")
print(f"wrote /app/PLAN.md with {len(TASKS)} tasks and 3 checkpoints")
PY
