---
schema_version: '1.3'
metadata:
  author_name: kalavero
  author_email: noreply@kalavero.local
  difficulty: hard
  difficulty_explanation: >
    The TAD expresses its build order in prose rather than a dependency list,
    so the agent must interpret it into depends_on edges, and three of the six
    tasks carry no point estimate, so the agent must size them itself on a
    relative-points scale — faithful copying of the document is not enough.
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
`/app/docs/tech-approaches/scheduled-report-exports.md` has been reviewed and
approved. Turn its "Proposed tasks" section into tickets.

This environment has no live issue tracker, so tickets are represented as JSON
files. Create one JSON file per ticket in `/app/tickets/`, named after the
ticket title in kebab-case (for example
`create-export-schedules-table.json`). Each file must contain a single JSON
object with exactly these fields:

- `title` (string): the ticket's title.
- `description` (string, markdown): a self-contained description — everything
  an engineer needs to start the work without any other context, including a
  reference to the TAD document.
- `estimate` (integer): a relative point estimate for the work.
- `depends_on` (array of strings): the file names of the tickets that must be
  completed before this one (for example
  `["create-export-schedules-table.json"]`), or an empty array if there are
  none.
- `source_task` (string): the exact title of the TAD task this ticket
  implements.

Where the TAD gives a task a point estimate, carry it over; where it gives
none, assign a relative point estimate yourself based on the work described.
The TAD describes the build order in prose in its "Sequencing" section —
interpret it and encode those ordering constraints in `depends_on`. Every
proposed task in the TAD must end up represented in the tickets you create.
Write valid JSON only — the files are parsed programmatically.
