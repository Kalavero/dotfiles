# Feature Spec: Report Exports

## Context

This repository is a small Python web application for tracking users and
projects:

- `app/models.py` — dataclass domain models (`User`, `Project`)
- `app/storage.py` — SQLite persistence (`Storage`) with file-based
  migrations in `migrations/` (`NNNN_name.sql`, applied in sorted order)
- `app/api.py` — a stdlib `http.server` JSON API (`/users`, `/projects`)
- `app/cli.py` — an argparse CLI (`user`, `project`, `summary` commands)
- `app/reports.py` — the existing ad-hoc usage summary behind `summary`

Tests live in `tests/` and run with `python -m unittest discover -s tests`
from `/app`.

## The Feature

We are adding **report exports**: on-demand exports of the app's data in
three formats, tracked in the database.

### 1. The `reports` table (shared foundation)

Every export run is recorded in a new `reports` table, added through a new
migration file in `migrations/`. Columns: `id`, `format`
(`csv`/`json`/`markdown`), `status` (`pending`/`running`/`done`/`failed`),
`params` (JSON text), `output_path`, `created_at`, `finished_at`.

Everything else in this feature reads or writes this table. The storage
layer also needs small helper methods for recording a run and updating its
status.

### 2. Three exporters

Three exporter modules under a new `app/exporters/` package, one per
format:

- `csv_exporter.py` — users and projects as CSV
- `json_exporter.py` — the full dataset as pretty-printed JSON
- `markdown_exporter.py` — a human-readable Markdown summary report

Each exporter takes a `Storage` instance and an output directory, writes
its file, and returns the output path. **The three exporters are
independent of one another**: each can be built, tested, and shipped
without the others. All three depend on the `reports` table and storage
helpers above.

### 3. Interfaces

- API: `POST /reports` (run an export, body `{"format": ...}`),
  `GET /reports` (list runs), `GET /reports/{id}` (one run with its
  output path).
- CLI: a `report` command group (`report run --format csv|json|markdown`,
  `report list`, `report show ID`).

## Constraints

- Standard library only.
- Exports are written under an `exports/` directory created on demand.
- New behavior needs new tests alongside the existing ones in `tests/`.
- Existing `user`/`project`/`summary` behavior must keep working.

## Team context

Three engineers are available next week, so work that can proceed
concurrently should. Note that the exporters all need the shared
foundation first, and that they add small, adjacent routes and commands to
the same `app/api.py` and `app/cli.py` files.

## Out of scope

- Async/background execution (exports run synchronously).
- Downloading export files over the API (the run record carries the path).
- Scheduling recurring exports.
