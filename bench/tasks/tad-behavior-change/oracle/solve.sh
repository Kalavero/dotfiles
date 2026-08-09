#!/bin/bash
# Oracle: explore /app, then write a compliant technical-approach document
# that cites only paths verified to exist (new files are marked as such)
# and diagrams the behavior change with a Today/After mermaid pair.
set -euo pipefail

python3 <<'PY'
import pathlib
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
    "orders/models.py",
    "orders/service.py",
    "orders/refunds.py",
    "orders/store.py",
    "orders/api.py",
    "tests/test_models.py",
    "tests/test_service.py",
]
missing = [c for c in cited if c not in files]
if missing:
    sys.exit(f"expected repo files not found: {missing}")

# Sanity-read the modules the doc describes.
service_src = (APP / "orders/service.py").read_text()
models_src = (APP / "orders/models.py").read_text()
assert "def cancel_order(" in service_src, "service.py lost cancel_order()"
assert "TRANSITIONS" in models_src, "models.py lost the transition table"

doc = """\
# Two-Phase Order Cancellation — Technical Approach

PRD: `PRD.md`

## Goal

Replace the immediate, all-or-nothing `cancel_order` in `orders/service.py`
with a two-phase flow: customers request cancellation, the order waits in a
new `cancellation_requested` state, and approval — merchant or 24-hour
auto-approve — cancels the order and runs the refund branch that matches its
fulfillment stage.

## Open questions

- Should auto-approve run on a fixed schedule or per-request deadlines? A
  periodic sweeper is assumed below; confirm with ops.

## Assumptions

- The restocking fee is 15% of the order total, per `PRD.md`.
- The feature ships behind a new feature flag: `two_phase_cancellation`,
  checked at the API entry point in `orders/api.py`.
- `orders/refunds.py` already exposes `refund(order_id, amount_cents,
  reason)`, so partial refunds need no provider changes.
- Notifications are log lines only (per the `PRD.md` non-goals).

## Approach

Cancellation becomes a small state machine instead of a single function.
`orders/models.py` gains the `cancellation_requested` status and its
transitions (into it from pending/paid/fulfilled/shipped, out of it to
cancelled on approval or back to the originating status on denial). A new
module, `orders/cancellations.py` (new), owns the request/approve/deny logic
and the refund-branch decision: full refund via `full_refund` in
`orders/refunds.py` when not yet fulfilled, partial refund minus the
restocking fee when fulfilled or shipped, denial when delivered. A new
sweeper process, `orders/sweeper.py` (new), auto-approves requests older
than 24 hours on unfulfilled orders. `orders/api.py` exposes the three new
endpoints and keeps today's immediate-cancel behavior on the flag-off path.

## Scope

In:

- New `cancellation_requested` status and transitions in `orders/models.py`
- Request, approve, and deny endpoints in `orders/api.py`
- Refund branches: full, partial minus 15% restocking fee, deny-when-delivered
- Sweeper process for 24-hour auto-approve of unfulfilled orders

Out:

- The returns flow that denied (delivered) customers are routed to
- Item-level partial cancellation
- Email or push notifications

## Flow

The change replaces a single synchronous decision with a two-phase flow and
three refund branches.

#### Today

```mermaid
flowchart TD
  A[Customer asks to cancel] --> B{Order status}
  B -->|pending| C[cancelled, no refund]
  B -->|paid| D[full refund] --> C
  B -->|fulfilled or later| E[rejected, support handles manually]
```

#### After

```mermaid
flowchart TD
  A[Customer requests cancellation] --> B[cancellation_requested]
  B --> C{Fulfilled?}
  C -->|no| D[sweeper auto-approves after 24h, or merchant approves] --> E[full refund] --> F[cancelled]
  C -->|fulfilled or shipped| G[merchant review] --> H[partial refund minus restocking fee] --> F
  C -->|delivered| I[request denied, routed to returns]
```

New branches: the 24-hour auto-approve path, the merchant approve/deny
decision, and the three-way refund split (full, partial minus fee, denied).

## Proposed tasks

### 1. New status and transitions

Add `cancellation_requested` to STATUSES and TRANSITIONS in
`orders/models.py`, including the deny transition back to the originating
status. Cover the legal and illegal transitions in `tests/test_models.py`.

### 2. Cancellation service

Create `orders/cancellations.py` (new): request, approve, deny, and the
refund-branch decision, persisting through `orders/store.py` and refunding
through `orders/refunds.py`. Covered by `tests/test_cancellations.py` (new),
including the restocking-fee math.

### 3. API endpoints and flag

Add the request/approve/deny routes to `orders/api.py`. With
`two_phase_cancellation` off, `POST /orders/{id}/cancel` keeps calling the
existing `cancel_order` in `orders/service.py`; with it on, cancel becomes a
cancellation request. Extend `tests/test_service.py` so the legacy path
keeps passing.

### 4. Auto-approve sweeper

Create `orders/sweeper.py` (new): a loop that finds requests older than 24
hours on unfulfilled orders and approves them, logging each auto-approval.
Add a CLI entry point so ops can run it on a schedule.

### Sequencing

Task 1 lands first; tasks 2 and 4 both depend on it but can proceed in
parallel with each other. Task 3 depends on 2. The sweeper (4) only needs to
be live before the flag is enabled.

## Test plan

- How we know it works: a paid order moves to `cancellation_requested` on
  request and auto-approves after 24 hours with a full refund; a shipped
  order gets the 15%-fee partial refund on merchant approval; a delivered
  order is denied; legacy immediate cancel still works with the flag off.
- How we know if it's broken: requests stuck in `cancellation_requested`
  past 24 hours, refund amounts that do not match the branch, or sweeper log
  silence — all checkable through the store and logs.

## Rollout

Ship behind `two_phase_cancellation` (default off), so production keeps the
current immediate-cancel behavior. Enable for a small set of accounts, watch
stuck requests and refund amounts, then enable for all. After two stable
weeks, remove the flag, the legacy `cancel_order` path in
`orders/service.py`, and the old endpoint wiring.
"""

out = APP / "docs/tech-approaches/two-phase-order-cancellation.md"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(doc)
print(f"wrote {out}")
PY
