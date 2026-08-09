from shop import pricing
from shop.shipping import delivery_quote_cents


def test_delivery_quote_matches_base_price():
    # A plain order with no extras should quote at exactly the base price.
    assert delivery_quote_cents(2000) == 2000


def test_standard_us_tax_rate():
    assert pricing.tax_rate_for("US") == 0.20
