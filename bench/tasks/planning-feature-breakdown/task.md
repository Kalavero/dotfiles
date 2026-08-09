---
schema_version: '1.3'
metadata:
  author_name: kalavero
  author_email: noreply@kalavero.local
  difficulty: medium
  difficulty_explanation: >
    The spec is a genuinely multi-layer feature (storage, API, CLI, tests)
    with interdependent parts, so a usable plan requires decomposing it
    into small, correctly ordered, individually verifiable tasks rather
    than restating the requirements or splitting by technical layer.
  category: software-engineering
  subcategory: task-breakdown
  category_confidence: high
  task_type:
    - planning
  modality:
    - source-code
  interface:
    - terminal
  skill_type:
    - domain-procedure
    - planning
  tags:
    - python
    - planning
    - task-breakdown
    - decomposition
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

A small Python web application lives in `/app` (package `app/`, tests in
`tests/`). `/app/SPEC.md` describes a new team-workspaces feature to add to
it.

Write an implementation plan for the feature to `/app/PLAN.md`.

The plan will be handed to another engineer, or to an automated coding
agent, who has never seen this repository. They must be able to execute it
top to bottom without asking you questions and without making design
decisions you already had the information to make. Break the work into
ordered tasks that are each small enough to implement and verify in a
single focused work session, and make the order safe: nothing may be
scheduled before the work it relies on.

Explore the code under `/app` before writing, so the plan refers to real
files and follows the project's existing patterns.

Write only `/app/PLAN.md`. Do not modify or create any other file, and do
not implement the feature.
