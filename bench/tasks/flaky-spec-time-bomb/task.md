---
schema_version: '1.3'
metadata:
  author_name: kalavero
  author_email: noreply@kalavero.local
  difficulty: medium
  difficulty_explanation: >
    The suite contains a time bomb that has already gone off: tests pin a
    hard-coded signup date that has since aged out of the 30-day trial
    window. The agent must recognize the datetime.now() boundary as the
    root cause and make the tests time-independent by freezing time, rather
    than bumping the date (which re-bombs later) or masking with sleeps.
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
    - time-dependent
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

A small Python billing module lives in `/app` (`/app/billing.py`), with its
pytest suite in `/app/tests/test_billing.py`. It implements trial-expiry
checks: a customer's trial is active for 30 days after their signup
timestamp.

The nightly CI job runs:

```
cd /app && python -m pytest -q
```

Teammates report the suite "passes on some days and fails on others". The
CI history is in `/app/ci-log.txt`: green through 2026-08-04, then the same
two tests started failing every night with no code changes.

Find the root cause and fix it so the suite is reliably green no matter
what date it runs on. Constraints:

- Do not change the business logic in `/app/billing.py`; the trial window
  behavior is correct and depended on elsewhere.
- Do not add retries or sleeps; those mask the failure instead of fixing
  it.
- A fix that only works until some future date is not a fix.

Re-run the suite to convince yourself it is green. Finish by writing a
short summary of the root cause and your fix to `/app/flake_report.md`.
