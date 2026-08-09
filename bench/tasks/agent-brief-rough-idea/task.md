---
schema_version: '1.3'
metadata:
  author_name: kalavero
  author_email: noreply@kalavero.local
  difficulty: medium
  difficulty_explanation: >
    The idea is deliberately vague; the work is interviewing the repository
    rather than the user — finding the real hot path, the contractual CSV
    format, and the actual test command — then writing a brief that stands
    alone with checkable acceptance criteria and honest non-goals.
  category: software-engineering
  subcategory: task-brief-writing
  category_confidence: high
  task_type:
    - generation
    - analysis
  modality:
    - source-code
    - documents
  interface:
    - terminal
  skill_type:
    - domain-procedure
  tags:
    - agent-brief
    - delegation
    - caching
    - python
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

The repository at `/app` is a small Python CLI tool. `/app/IDEA.md` contains
a rough feature idea from the tool's maintainer — vague, conversational, and
missing most of what an implementer would need.

Turn that idea into a brief that an AI coding agent with zero conversation
context could execute without follow-up questions, and write it to
`/app/tasks/brief-<slug>.md` (pick a short kebab-case slug for the idea).

Ground the brief in the actual repository: explore the code before writing,
cite real paths, and use the verification commands this project actually
has. Do not invent files or features that do not exist.
