---
schema_version: '1.3'
metadata:
  author_name: kalavero
  author_email: noreply@kalavero.local
  difficulty: medium
  difficulty_explanation: >
    On top of the groundedness and structure demands of a design doc, the
    feature changes runtime behavior — a new order state, new branches, a new
    background process — so the document must also make the before/after
    behavior legible rather than only listing tasks.
  category: software-engineering
  subcategory: technical-design-doc
  category_confidence: high
  task_type:
    - planning
    - analysis
  modality:
    - source-code
    - document
  interface:
    - terminal
  skill_type:
    - domain-procedure
    - document-structure
  tags:
    - python
    - design-doc
    - technical-approach
    - planning
    - state-machine
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

A small Python order service lives in `/app` (source under `/app/orders`,
tests under `/app/tests`). The product team has written `/app/PRD.md`
describing a change to how order cancellation works: a two-phase
cancellation-request flow with a new order state and several refund branches.

Write a technical approach document for implementing the change. Save it as
a markdown file under `/app/docs/tech-approaches/`, named `<slug>.md` where
`<slug>` is a kebab-case name derived from the feature (for example
`docs/tech-approaches/two-phase-order-cancellation.md`).

Explore the code in `/app` before writing. The document is for engineers who
will pick up the implementation work. It must state the goal, what you are
taking as given, the approach, what is in and out of scope, the proposed
implementation tasks in a sensible order, a high-level test plan, and a
rollout plan. Reference only files, modules, and patterns that actually exist
in `/app`; when you reference a file you intend to create, say so explicitly.
