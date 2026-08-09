"""Thin happy-path tests for the pricing engine."""

from pricing import price_order, set_region


def setup_function():
    set_region("CA")


def test_simple_order_total():
    rec = price_order([("book", 20.0, 2)])
    assert rec["subtotal"] == 40.0
    assert rec["tax"] == 3.4
    assert rec["total"] == 43.4


def test_promo_discount():
    rec = price_order([("book", 20.0, 2)], promo="WELCOME10")
    assert rec["discount"] == 4.0
    assert rec["total"] == 39.06
