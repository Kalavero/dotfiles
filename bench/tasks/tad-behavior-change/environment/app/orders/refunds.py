"""Thin wrapper around the payment provider's refund API (stubbed)."""

import uuid


class RefundClient:
    def __init__(self):
        self.issued = []

    def refund(self, order_id, amount_cents, reason):
        receipt = {
            "id": f"re_{uuid.uuid4().hex[:12]}",
            "order_id": order_id,
            "amount_cents": amount_cents,
            "reason": reason,
        }
        self.issued.append(receipt)
        return receipt

    def full_refund(self, order, reason="cancellation"):
        remaining = order.total_cents - order.refunded_cents
        return self.refund(order.id, remaining, reason)
