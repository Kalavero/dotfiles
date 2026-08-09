---
schema_version: '1.3'
metadata:
  author_name: kalavero
  author_email: noreply@kalavero.local
  difficulty: hard
  difficulty_explanation: >
    One TAD task carries an 8-point estimate — high complexity with critical
    unknowns — and must be broken into smaller tickets before ticketing rather
    than copied verbatim, while the neighboring 5-point task is legitimately
    ticketed as-is; the sequencing DAG must survive the split.
  category: software-engineering
  subcategory: task-breakdown
  category_confidence: high
  task_type:
    - generation
    - planning
  modality:
    - documents
  interface:
    - terminal
  skill_type:
    - domain-procedure
  tags:
    - tad
    - tickets
    - planning
    - estimation
verifier:
  type: test-script
  timeout_sec: 900.0
agent:
  timeout_sec: 1800.0
sandbox:
  network_mode: public
  build_timeout_sec: 600.0
  os: linux
  cpus: 1
  memory_mb: 4096
  storage_mb: 10240
  gpus: 0
---

The technical approach document at
`/app/docs/tech-approaches/customer-notification-center.md` has been reviewed
and approved. Turn its "Proposed tasks" section into tickets.

This environment has no live issue tracker, so tickets are represented as JSON
files. Create one JSON file per ticket in `/app/tickets/`, named after the
ticket title in kebab-case (for example
`create-notifications-schema.json`). Each file must contain a single JSON
object with exactly these fields:

- `title` (string): the ticket's title.
- `description` (string, markdown): a self-contained description — everything
  an engineer needs to start the work without any other context, including a
  reference to the TAD document.
- `estimate` (integer): a relative point estimate for the work.
- `depends_on` (array of strings): the file names of the tickets that must be
  completed before this one (for example
  `["create-notifications-schema.json"]`), or an empty array if there are
  none.
- `source_task` (string): the exact title of the TAD task this ticket
  implements.

Use the TAD's own per-task estimates and its "Sequencing" section as the
source of truth. Every proposed task in the TAD must end up represented in
the tickets you create. Write valid JSON only — the files are parsed
programmatically.
