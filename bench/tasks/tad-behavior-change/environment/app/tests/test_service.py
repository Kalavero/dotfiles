import tempfile
import unittest

from orders.models import Order
from orders.refunds import RefundClient
from orders.service import CancellationError, cancel_order
from orders.store import Store


class CancelOrderTest(unittest.TestCase):
    def setUp(self):
        self.store = Store(tempfile.mkdtemp())
        self.refunds = RefundClient()

    def _order(self, status, total=5000):
        order = Order(id="o1", account_id="a1", total_cents=total, status=status)
        self.store.save_order(order)
        return order

    def test_cancel_pending_no_refund(self):
        self._order("pending")
        order = cancel_order(self.store, self.refunds, "o1")
        self.assertEqual(order.status, "cancelled")
        self.assertEqual(self.refunds.issued, [])

    def test_cancel_paid_full_refund(self):
        self._order("paid")
        order = cancel_order(self.store, self.refunds, "o1")
        self.assertEqual(order.status, "cancelled")
        self.assertEqual(order.refunded_cents, 5000)

    def test_cancel_shipped_rejected(self):
        self._order("shipped")
        with self.assertRaises(CancellationError):
            cancel_order(self.store, self.refunds, "o1")

    def test_unknown_order_rejected(self):
        with self.assertRaises(CancellationError):
            cancel_order(self.store, self.refunds, "nope")


if __name__ == "__main__":
    unittest.main()
