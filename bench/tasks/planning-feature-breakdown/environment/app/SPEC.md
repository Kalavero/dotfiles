# Feature Spec: Team Workspaces

## Context

This repository is a small Python web application for tracking users and
projects. It has three layers:

- `app/models.py` — dataclass domain models (`User`, `Project`)
- `app/storage.py` — JSON-file persistence (`Storage`)
- `app/api.py` — a stdlib `http.server` JSON API (`/users`, `/projects`)
- `app/cli.py` — an argparse CLI (`user create/list`, `project create/list`)

Tests live in `tests/` and run with `python -m unittest discover -s tests`
from `/app`.

## The Feature

We are adding **team workspaces**: shared containers that group users and
the projects they collaborate on. The feature has four parts.

### 1. Workspaces and membership

- A workspace has a name, a URL-safe slug, and an owner.
- Users join a workspace as members. Every member has a role:
  `owner`, `admin`, or `member`.
- Owners and admins can add or remove members and change a member's role.
  A workspace must always have at least one owner.

### 2. Invites

- Members with the `owner` or `admin` role invite new users by email.
- An invite carries a unique token and expires after 7 days.
- The invited user accepts or declines with the token. Accepting creates a
  membership with the `member` role.
- Pending (unexpired, unanswered) invites can be listed per workspace.

### 3. Audit log

- Every workspace event is recorded: workspace created, member added,
  member removed, role changed, invite sent, invite accepted, invite
  declined.
- Each audit entry has a timestamp, the actor, the action, and the target.
- The audit log for a workspace can be listed, newest first.

### 4. Interfaces

Everything above must be reachable through both interfaces, following the
existing patterns in `app/api.py` and `app/cli.py`:

- API: endpoints under `/workspaces` (create workspace, manage members,
  send/answer invites, read the audit log).
- CLI: a `workspace` command group (`create`, `members`, `invite`,
  `accept`, `decline`, `audit`).

## Constraints

- Standard library only; keep the existing `Storage` JSON-file approach.
- New behavior needs new tests alongside the existing ones in `tests/`.
- Existing `user` and `project` behavior must keep working.

## Out of scope

- Real email delivery (invites are created and answered by token only).
- Authentication/permissions enforcement on the API beyond role checks in
  the membership logic.
- Grouping projects into workspaces (a later feature).
