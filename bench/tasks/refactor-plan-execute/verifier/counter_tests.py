"""Hidden counter-side-effect suite for the shipping refactor task.

Pins the `quotes_issued()` counter semantics of the original module —
behavior the provided plan does NOT document:

1. Every `quote_shipping` call increments the counter by one, and
   `quote_order` routes each parcel through it, so an order grows the
   counter by its parcel count.
2. The counter increments BEFORE the zone lookup, so a quote that fails
   with KeyError still counts.
3. An empty order quotes nothing and leaves the counter untouched.

Mounted only at verify time; must pass against both the original module and
a faithful refactor.
"""

import pytest

import shipping


@pytest.fixture(autouse=True)
def reset_surcharge():
    shipping.set_fuel_surcharge(0.07)
    yield
    shipping.set_fuel_surcharge(0.07)


def test_counter_increments_once_per_parcel():
    before = shipping.quotes_issued()
    shipping.quote_shipping(0.5, "local")
    shipping.quote_order([1.0, 2.0, 3.0], "regional")
    assert shipping.quotes_issued() == before + 4


def test_failed_quote_still_increments_counter():
    before = shipping.quotes_issued()
    with pytest.raises(KeyError):
        shipping.quote_shipping(1, "moon")
    assert shipping.quotes_issued() == before + 1


def test_empty_order_quotes_nothing():
    before = shipping.quotes_issued()
    result = shipping.quote_order([], "local")
    assert result == {"zone": "local", "parcels": 0, "quotes": [], "total": 0.0}
    assert shipping.quotes_issued() == before
