# PRD: Two-Phase Order Cancellation

## Background

Today cancellation is immediate and all-or-nothing: `cancel_order` in
`orders/service.py` flips a pending order to cancelled, issues an automatic
full refund for a paid order, and rejects anything fulfilled or beyond. The
rejected cases land in a support queue and are refunded by hand — last
quarter that was 1,900 manual refunds and our top support-driver.

## Goals

Introduce a cancellation-request flow. Customers request a cancellation; the
order waits in a new `cancellation_requested` state; approval — by a
merchant, or automatically after 24 hours — cancels the order and runs the
correct refund branch for the order's fulfillment stage.

- New order state: `cancellation_requested`.
- Refund policy on approval:
  - not yet fulfilled → full refund
  - fulfilled or shipped but not delivered → partial refund: order total
    minus a 15% restocking fee, issued when the return is initiated
  - delivered → cancellation denied; the customer is routed to the returns
    process (out of scope)
- Approval: auto-approve after 24 hours if the order has not reached
  fulfillment; a merchant may approve or deny earlier.
- New endpoints:
  - `POST /orders/{id}/cancellation-requests`
  - `POST /cancellation-requests/{id}/approve`
  - `POST /cancellation-requests/{id}/deny`
  - `GET /orders/{id}` shows the new state
- A background sweeper process approves requests older than 24 hours on
  unfulfilled orders.

## Non-goals

- The returns flow itself (denied customers are routed there, nothing more).
- Item-level partial cancellation.
- Email or push notifications — log lines are enough for now.

## Acceptance criteria

- A paid order moves to `cancellation_requested` on request and is
  auto-approved with a full refund 24 hours later if never fulfilled.
- A shipped order approved by a merchant receives a partial refund equal to
  the total minus the 15% restocking fee.
- A delivered order's request is denied and the order state is unchanged.
- With the feature disabled, cancellation behaves exactly as it does today.
