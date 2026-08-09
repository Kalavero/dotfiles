# PRD: Usage-Based API Rate Limiting

## Background

The widget inventory API is open to any caller holding a valid API key. Keys
are issued with a tier (free, pro, enterprise), but nothing today enforces
different service levels: a free-tier key can hammer the API as hard as an
enterprise one. Two free-tier accounts generated 70% of last month's request
volume and caused the only two availability incidents we have had.

## Goals

- Enforce per-tier request limits with two windows:
  - a short-term limit: requests per minute per API key
  - a long-term quota: requests per calendar month per API key
- Communicate limits on every authenticated response:
  - `X-RateLimit-Limit` — the ceiling for the current minute window
  - `X-RateLimit-Remaining` — requests left in the current minute window
  - `X-RateLimit-Reset` — unix timestamp when the current window resets
- Reject over-limit requests with `429 Too Many Requests` and a `Retry-After`
  header.
- Give operators visibility: `GET /admin/usage/{key}` returns the current
  minute-window usage and month-to-date usage for a key. Restricted to keys
  marked as admin.

## Tiers and limits

| Tier       | Per-minute | Per-month  |
|------------|-----------:|-----------:|
| free       | 60         | 10,000     |
| pro        | 600        | 1,000,000  |
| enterprise | 6,000      | 10,000,000 |

## Non-goals

- Distributed or multi-process limiting. We run a single process; in-process
  counters are acceptable.
- Per-key custom limit overrides.
- Billing, invoicing, or tier-upgrade flows.

## Acceptance criteria

- A free-tier key receives 429 on its 61st request within a minute.
- Headers decrement per request and reset at the window boundary.
- Month-to-date usage survives a process restart.
- With the feature disabled, behavior is byte-for-byte what it is today.
