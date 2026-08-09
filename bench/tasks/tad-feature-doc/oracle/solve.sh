#!/bin/bash
# Oracle: explore /app, then write a compliant technical-approach document
# that cites only paths verified to exist (new files are marked as such).
set -euo pipefail

python3 <<'PY'
import pathlib
import re
import sys

APP = pathlib.Path("/app")

# Explore the repo first: only cite what is actually there.
files = sorted(
    p.relative_to(APP).as_posix() for p in APP.rglob("*") if p.is_file()
)
print("repo files:")
for f in files:
    print(" ", f)

cited = [
    "PRD.md",
    "app/server.py",
    "app/auth.py",
    "app/store.py",
    "app/config.py",
    "tests/test_server.py",
    "tests/test_store.py",
]
missing = [c for c in cited if c not in files]
if missing:
    sys.exit(f"expected repo files not found: {missing}")

# Sanity-read the modules the doc describes.
server_src = (APP / "app/server.py").read_text()
auth_src = (APP / "app/auth.py").read_text()
assert "def application(" in server_src, "server.py lost its WSGI entry point"
assert "def authenticate(" in auth_src, "auth.py lost authenticate()"

doc = """\
# Usage-Based API Rate Limiting — Technical Approach

PRD: `PRD.md`

## Goal

Add per-tier, usage-based rate limiting to the widget API: a per-minute
request window plus a monthly quota per API key, standard `X-RateLimit-*`
response headers, 429 responses with `Retry-After`, and an operator usage
endpoint.

## Open questions

- Does the enterprise tier need per-key custom limits? The PRD lists it as a
  non-goal; treated as out of scope until sales confirms otherwise.

## Assumptions

- Tier limits come from `PRD.md`: free 60/min and 10k/month, pro 600/min and
  1M/month, enterprise 6000/min and 10M/month.
- Single-process deployment (per the `PRD.md` non-goals), so counters can
  live in the existing JSON store behind `app/store.py`; no external cache.
- The feature ships behind a new feature flag: `rate_limiting_enabled`, read
  from the environment in `app/config.py`.
- Callers are already identified with their tier by `app/auth.py`
  (`authenticate`); the limiter consumes that, no auth changes.

## Approach

The limiter is a pre-dispatch check inside `application` in `app/server.py`,
right after authentication. A new module `app/ratelimit.py` owns the policy:
given the caller's tier and the stored counters it decides allow/deny and
computes the header values. Counters (current minute window, month-to-date)
are persisted through new functions added to `app/store.py`, following the
same load/save JSON pattern the store already uses for widgets and API keys.
On allow, the headers are attached to the response; on deny, a 429 with
`Retry-After` is returned before routing. The admin usage endpoint is a new
route in `app/server.py` reading the same counters.

## Scope

In:

- Per-minute window and monthly quota per API key
- `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` headers
  on authenticated responses
- 429 with `Retry-After` when over limit
- New route `GET /admin/usage/{key}` returning window and month-to-date usage

Out:

- Distributed or multi-process limiting
- Per-key custom limit overrides
- Billing or invoicing integration

## Proposed tasks

### 1. Usage counters in the store

Add two counters per key to `app/store.py`: a minute-window counter (window
start plus count) and a month-to-date counter, with read-modify-write under
the store's existing lock. Extend `tests/test_store.py` to cover window
rollover and month boundaries.

### 2. Rate limiter module

Create `app/ratelimit.py` (new): pure policy that takes a tier, the current
counters, and now, and returns allow/deny plus header values. The tier
limits from the PRD table live here as a constant. Covered by
`tests/test_ratelimit.py` (new).

### 3. Server integration and headers

Wire the limiter into `application` in `app/server.py` after `authenticate`
from `app/auth.py`, attach headers on success, short-circuit 429 on deny.
Gate the whole check on the `rate_limiting_enabled` flag from
`app/config.py`. Extend `tests/test_server.py` for the 200-with-headers and
429 paths.

### 4. Admin usage endpoint

Add the `GET /admin/usage/{key}` route to `app/server.py`, restricted to
keys whose record in `app/store.py` marks an admin tier. The response shape
mirrors the PRD: current window and month-to-date usage.

### Sequencing

Tasks 1 and 2 can start in parallel — 2 depends on 1 only for the counter
shape, which is fixed up front. Task 3 depends on both. Task 4 depends on 3
and can land in the same release behind the flag.

## Test plan

- How we know it works: a free-tier key gets 429 on its 61st request in a
  minute; headers decrement per request and reset at the window boundary; a
  pro key is unaffected; the admin endpoint reports the same numbers the
  limiter enforces.
- How we know if it's broken: a sudden rise in 429s per tier, month-to-date
  counters not advancing, or limits applied while the flag is off — all
  visible from server logs and the admin endpoint.

## Rollout

Ship dark behind `rate_limiting_enabled` (default off in `app/config.py`).
Enable in staging, then for free-tier keys only, then all tiers. After two
stable weeks with no false 429s, remove the flag and the disabled branch,
and make the limiter unconditional.
"""

out = APP / "docs/tech-approaches/usage-based-rate-limiting.md"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(doc)
print(f"wrote {out}")
PY
