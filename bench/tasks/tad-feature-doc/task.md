---
schema_version: '1.3'
metadata:
  author_name: kalavero
  author_email: noreply@kalavero.local
  difficulty: medium
  difficulty_explanation: >
    The writing itself is straightforward; the hard part is grounding. The
    document must cite only files and modules that actually exist in the
    small repo (the tempting move is to invent plausible-looking paths),
    name a feature flag in the assumptions with a removal step in the
    rollout, and break the work into sequenced tasks.
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

A small Python web service lives in `/app` (source under `/app/app`, tests
under `/app/tests`). The product team has written `/app/PRD.md` describing a
new feature: usage-based API rate limiting with per-tier limits.

Write a technical approach document for implementing the feature. Save it as
a markdown file under `/app/docs/tech-approaches/`, named `<slug>.md` where
`<slug>` is a kebab-case name derived from the feature (for example
`docs/tech-approaches/usage-based-rate-limiting.md`).

Explore the code in `/app` before writing. The document is for engineers who
will pick up the implementation work. It must state the goal, what you are
taking as given, the approach, what is in and out of scope, the proposed
implementation tasks in a sensible order, a high-level test plan, and a
rollout plan. Reference only files, modules, and patterns that actually exist
in `/app`; when you reference a file you intend to create, say so explicitly.
