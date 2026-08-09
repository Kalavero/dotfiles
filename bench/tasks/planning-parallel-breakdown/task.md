---
schema_version: '1.3'
metadata:
  author_name: kalavero
  author_email: noreply@kalavero.local
  difficulty: medium
  difficulty_explanation: >
    The spec mixes genuinely independent work (three exporter slices) with
    one shared foundation (a new database table and migration) that
    everything else depends on, so a usable plan requires small ordered
    tasks plus a correct call on what can run concurrently and what must
    land first.
  category: software-engineering
  subcategory: parallel-task-breakdown
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
    - parallelization
    - sqlite
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

A small Python web application lives in `/app` (package `app/`, migrations
in `migrations/`, tests in `tests/`). `/app/SPEC.md` describes a new
report-exports feature to add to it, and a team context in which several
engineers are available to work on it at the same time.

Write an implementation plan for the feature to `/app/PLAN.md`.

The plan will be handed to a team of engineers (or automated coding
agents) who have never seen this repository. They must be able to execute
it without asking you questions. Break the work into ordered tasks that
are each small enough to implement and verify in a single focused work
session, and make the order safe: nothing may be scheduled before the work
it relies on. Because the team works concurrently, the plan must make
clear which tasks can proceed at the same time and which cannot.

Explore the code under `/app` before writing, so the plan refers to real
files and follows the project's existing patterns.

Write only `/app/PLAN.md`. Do not modify or create any other file, and do
not implement the feature.
