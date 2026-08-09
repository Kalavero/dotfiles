---
schema_version: '1.3'
metadata:
  author_name: kalavero
  author_email: noreply@kalavero.local
  difficulty: hard
  difficulty_explanation: >
    The module's two quirks (fuel surcharge computed on the base rate only,
    and cent truncation instead of rounding) must survive the module-to-
    package split bit-for-bit; a hidden behavior suite pins exact return
    values at the boundary inputs, so any drift fails verification.
  category: software-engineering
  subcategory: refactoring-execution
  category_confidence: high
  task_type:
    - code-modification
    - verification
  modality:
    - source-code
  interface:
    - terminal
  skill_type:
    - domain-procedure
    - execution-protocol
  tags:
    - python
    - refactoring
    - characterization-tests
    - execution
verifier:
  type: test-script
  timeout_sec: 900.0
agent:
  timeout_sec: 3600.0
sandbox:
  network_mode: public
  build_timeout_sec: 600.0
  os: linux
  cpus: 1
  memory_mb: 4096
  storage_mb: 10240
  gpus: 0
---

`/app/shipping.py` is a shipping cost calculator: weight tiers, destination
zones, and a fuel surcharge, tangled together in one module with
module-level state. The only tests are two happy-path tests in
`/app/tests/test_shipping.py` (run the suite with `python3 -m pytest` from
`/app`).

A step-by-step refactoring plan has already been written at
`/app/tasks/refactor-shipping.md`. Execute it.

Work through the plan in order, exactly as written. When you are done:

- The split described in the plan has happened: the `shipping/` package
  exists with the modules the plan specifies, and the old `/app/shipping.py`
  is gone.
- The public functions named in the plan are still importable from
  `shipping` with unchanged signatures.
- Every observable behavior — including the ones the plan flags as quirks —
  is bit-for-bit identical to what the original module does.
- The full test suite in `/app/tests` passes.
