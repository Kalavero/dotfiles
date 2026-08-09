---
schema_version: '1.3'
metadata:
  author_name: kalavero
  author_email: noreply@kalavero.local
  difficulty: hard
  difficulty_explanation: >
    The module's two quirks (string-format rounding that sends 2.675 down
    to 2.67, and tax computed before the flat coupon comes off) are only
    discoverable by running the code; a plan that ignores them, or that
    bundles a fix for them into the refactor, fails verification.
  category: software-engineering
  subcategory: refactoring-planning
  category_confidence: high
  task_type:
    - analysis
    - planning
  modality:
    - source-code
  interface:
    - terminal
  skill_type:
    - domain-procedure
    - planning-protocol
  tags:
    - python
    - refactoring
    - characterization-tests
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

`/app/pricing.py` is a storefront pricing engine: promo discounts, member
pricing, regional sales tax, flat coupons, and cash rounding are all tangled
together in one module, with module-level state and long functions. The only
tests are two happy-path tests in `/app/tests/test_pricing.py` (run them with
`python3 -m pytest` from `/app`).

The team wants the module split into separate discount, tax, and
rounding/money components without any observable behavior changing.

Write a safe, step-by-step refactoring plan to `/app/refactor-pricing.md`.

The plan must:

- Be grounded in what the code actually does today. Run the module, probe
  edge cases, and record every observable behavior you find — including any
  behavior that looks wrong. Behavior that looks wrong must be preserved
  exactly as it is; changing it is a different piece of work, not part of
  this refactor.
- Account for the thin test coverage: establish a safety net of tests that
  pin the current behavior before any restructuring begins.
- Include an explicit contract listing the observable behaviors (return
  values, side effects, error shapes, public API surface) that must not
  change, with the concrete values you observed.
- Break the work into small, numbered steps that are each independently
  verifiable, with the test suite passing after every step.
- Keep purely mechanical edits (moves, renames) in their own steps, separate
  from steps that require restructuring judgment.
