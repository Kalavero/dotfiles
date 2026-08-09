---
schema_version: '1.3'
metadata:
  author_name: kalavero
  author_email: noreply@kalavero.local
  difficulty: medium
  difficulty_explanation: >
    The failure only appears for certain random test orderings, so the agent
    must reproduce with the given seed, recognize order-dependent state
    leakage across test files, and clean up the polluter instead of
    weakening the victim test or masking the flake with retries.
  category: software-engineering
  subcategory: flaky-test-triage
  category_confidence: high
  task_type:
    - debugging
    - code-modification
  modality:
    - source-code
  interface:
    - terminal
  skill_type:
    - domain-procedure
    - evaluation-protocol
  tags:
    - python
    - pytest
    - flaky-test
    - order-dependent
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

A small Python shop package lives in `/app`, with its pytest suite in
`/app/tests`. The suite is run with pytest-randomly, so test order is
shuffled per seed.

CI runs:

```
cd /app && python -m pytest -q --randomly-seed=8
```

and that run fails two tests in `tests/test_checkout_baseline.py`:
`test_delivery_quote_matches_base_price` (`assert 6000 == 2000`) and
`test_standard_us_tax_rate` (`assert 0.0 == 0.2`). Other seeds fail one,
both, or neither of them, and the file passes when run on its own, so this
is intermittent and CI is red only for some seeds.

Find the root cause(s) and fix them so the suite is green for every seed,
not just this one. Constraints:

- Do not modify, skip, or delete the failing tests; they encode the
  intended behavior of the code under test.
- Do not add retries, reruns, or sleeps; those mask the failure instead of
  fixing it.
- The suite must still run under pytest-randomly with arbitrary seeds.

Re-run the failing CI command (and enough other seeds) to convince yourself
the failure is gone. Finish by writing a short summary of the root cause
and your fix to `/app/flake_report.md`.
