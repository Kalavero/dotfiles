---
schema_version: '1.3'
metadata:
  author_name: kalavero
  author_email: noreply@kalavero.local
  difficulty: medium
  difficulty_explanation: >
    The failing test points at the rendered output, so the tempting fix is
    to deduplicate in the presentation layer; the actual defect is JOIN
    fan-out in the query layer, and a correct fix must collapse the rows
    without dropping any of a user's roles.
  category: software-engineering
  subcategory: debugging-root-cause
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
    - sqlite
    - pytest
    - debugging
    - sql-join
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

The user directory app in `/app` has a failing test suite. One test fails:

```
tests/test_users.py::test_render_lists_each_user_exactly_once
AssertionError: Ada Lovelace appears 3 times in the rendered user list
```

The app is plain Python with a stdlib `sqlite3` database: `seed.py` builds
the data, `queries.py` reads it, `render.py` presents it. You can reproduce
with `cd /app && python3 -m pytest tests -q`.

Find and fix the root cause of the duplicates. The rendered list must show
each user exactly once **and** must still show every role that user holds —
collapsing a user with three roles down to one role is not a fix. Treat the
rendering layer and the existing tests as the specification of correct
behavior.

When you are done:

1. The full test suite in `/app/tests` passes.
2. You have added a new regression test under `/app/tests` that fails
   without your fix and passes with it.
3. You have written a brief summary of the root cause and why your fix
   addresses it to `/app/CAUSE.md`.
