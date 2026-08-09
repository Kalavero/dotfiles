---
schema_version: '1.3'
metadata:
  author_name: kalavero
  author_email: noreply@kalavero.local
  difficulty: hard
  difficulty_explanation: >
    The failure is a read-modify-write race that only surfaces under
    thread load and disappears on re-run, so the tempting moves are to
    call the test flaky, add sleeps, or retry it; the actual fix is to
    make the stock check-and-decrement atomic.
  category: software-engineering
  subcategory: debugging-concurrency-race
  category_confidence: high
  task_type:
    - analysis
    - implementation
  modality:
    - source-code
  interface:
    - terminal
  skill_type:
    - domain-procedure
    - evaluation-protocol
  tags:
    - python
    - concurrency
    - race-condition
    - pytest
    - debugging
verifier:
  type: test-script
  timeout_sec: 900.0
agent:
  timeout_sec: 2400.0
sandbox:
  network_mode: public
  build_timeout_sec: 600.0
  os: linux
  cpus: 1
  memory_mb: 4096
  storage_mb: 10240
  gpus: 0
---

CI for the inventory app in `/app` fails intermittently on
`tests/test_load.py::test_no_oversell_under_load` — see the captured
failure in `/app/ci-log.txt`. The failure comes and goes: re-running the
same job usually passes, and the single-threaded tests in
`tests/test_inventory.py` never fail.

Reproduce the failure locally (it may take load, not a single run, to
make it show up), find the root cause, and fix it so the oversell cannot
happen. The load test harness encodes the required behavior — do not
weaken it, and do not paper over the race with delays or retries in the
app code.

When you are done:

1. `python3 -m pytest tests/test_load.py -q` passes three times in a row.
2. The full test suite in `/app/tests` passes.
3. You have added a new regression test under `/app/tests` that exercises
   concurrent purchases, fails without your fix, and passes with it.
4. You have written a brief summary of the root cause and why your fix
   addresses it to `/app/CAUSE.md`.
