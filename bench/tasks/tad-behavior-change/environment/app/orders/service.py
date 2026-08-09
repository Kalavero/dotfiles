"""Order operations, including today's immediate, all-or-nothing cancel."""


class CancellationError(Exception):
    pass


def cancel_order(store, refunds, order_id):
    """Cancel immediately: full refund if paid, hard reject after fulfillment."""
    order = store.get_order(order_id)
    if order is None:
        raise CancellationError(f"unknown order {order_id}")
    if order.status not in ("pending", "paid"):
        raise CancellationError(
            f"order {order_id} can no longer be cancelled (status: {order.status})"
        )
    if order.status == "paid":
        receipt = refunds.full_refund(order)
        order.refunded_cents += receipt["amount_cents"]
    order.transition("cancelled")
    store.save_order(order)
    return order
