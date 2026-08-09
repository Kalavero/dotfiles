import unittest

from orders.models import Order
from orders.refunds import RefundClient


class RefundClientTest(unittest.TestCase):
    def test_full_refund_covers_remaining_balance(self):
        refunds = RefundClient()
        order = Order(id="o1", account_id="a1", total_cents=5000,
                      status="paid", refunded_cents=1000)
        receipt = refunds.full_refund(order)
        self.assertEqual(receipt["amount_cents"], 4000)
        self.assertEqual(receipt["reason"], "cancellation")

    def test_partial_amounts_are_recorded(self):
        refunds = RefundClient()
        receipt = refunds.refund("o1", 4250, "partial")
        self.assertEqual(receipt["amount_cents"], 4250)
        self.assertEqual(len(refunds.issued), 1)


if __name__ == "__main__":
    unittest.main()
