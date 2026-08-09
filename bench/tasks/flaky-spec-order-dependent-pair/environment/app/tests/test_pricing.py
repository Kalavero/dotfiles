from shop import pricing


def test_total_with_tax_rounds_to_cents():
    assert pricing.total_with_tax(999, "FR") == 1209


def test_total_with_tax_de_region():
    assert pricing.total_with_tax(1000, "DE") == 1190


def test_bulk_discount_applies_at_ten_units():
    assert pricing.bulk_discount(2000, 10) == 1800
    assert pricing.bulk_discount(2000, 9) == 2000


def test_zero_rate_promo(monkeypatch):
    # Promo weekend: the US tax rate drops to zero.
    monkeypatch.setitem(pricing._BASE_TAX_RATES, "US", 0.0)
    pricing._rate_cache.clear()
    assert pricing.tax_rate_for("US") == 0.0
    assert pricing.total_with_tax(1000, "US") == 1000
