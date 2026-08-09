import unittest

from orders.models import Order, TransitionError


class TransitionTest(unittest.TestCase):
    def test_pending_can_be_paid_or_cancelled(self):
        order = Order(id="o1", account_id="a1", total_cents=5000)
        order.transition("paid")
        self.assertEqual(order.status, "paid")

    def test_illegal_transition_raises(self):
        order = Order(id="o1", account_id="a1", total_cents=5000)
        with self.assertRaises(TransitionError):
            order.transition("delivered")

    def test_cancelled_is_terminal(self):
        order = Order(id="o1", account_id="a1", total_cents=5000, status="cancelled")
        with self.assertRaises(TransitionError):
            order.transition("paid")


if __name__ == "__main__":
    unittest.main()
