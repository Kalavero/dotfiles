"""Thin happy-path tests for the shipping calculator."""

from shipping import quote_order, quote_shipping


def test_local_light_parcel():
    assert quote_shipping(0.5, "local") == 5.24


def test_order_totals_parcels():
    result = quote_order([0.5, 0.5], "local")
    assert result["parcels"] == 2
    assert result["total"] == 10.48
