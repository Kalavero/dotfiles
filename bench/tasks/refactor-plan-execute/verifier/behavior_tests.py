"""Hidden behavior suite for the shipping refactor task.

Pins the CURRENT behavior of the original /app/shipping.py exactly,
including its two quirks:

1. The fuel surcharge applies to the base tier rate only, never to the
   zone-multiplied amount.
2. Amounts are truncated toward zero at cents (int(x * 100) / 100), not
   rounded — 12.525 becomes 12.52, 8.025 becomes 8.02.

Every expected value below was produced by running the original module.
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


def test_national_midweight_truncates_and_surcharges_base_only():
    # base 7.50 * 1.6 = 12.00, surcharge 7.50 * 0.07 = 0.525 -> 12.525,
    # truncated (not rounded) to 12.52.
    assert shipping.quote_shipping(3, "national") == 12.52


def test_local_light_parcel():
    assert shipping.quote_shipping(0.5, "local") == 5.24


def test_tier_boundary_is_inclusive_then_truncates():
    assert shipping.quote_shipping(1.0, "local") == 5.24
    # 1.0001 kg falls into the 7.50 tier; 8.025 truncates to 8.02.
    assert shipping.quote_shipping(1.0001, "local") == 8.02


def test_overweight_bills_per_started_kg():
    # 3.2 kg over the 20 kg tier bills as 4 kg: base 19.80 + 4 * 0.85.
    assert shipping.quote_shipping(23.2, "remote") == 50.34
    assert shipping.quote_shipping(20, "regional") == 26.13
    assert shipping.quote_shipping(20.01, "local") == 22.09


def test_remote_ten_kg_parcel():
    assert shipping.quote_shipping(10.0, "remote") == 26.58


def test_fuel_surcharge_applies_to_base_rate_only():
    shipping.set_fuel_surcharge(0.10)
    # 12.00 + 7.50 * 0.10 = 12.75; a post-zone surcharge would give 13.20.
    assert shipping.quote_shipping(3, "national") == 12.75


def test_unknown_zone_raises_keyerror():
    with pytest.raises(KeyError):
        shipping.quote_shipping(1, "moon")


def test_quote_order_shape_and_values():
    result = shipping.quote_order([3, 0.5], "national")
    assert result == {
        "zone": "national",
        "parcels": 2,
        "quotes": [12.52, 8.18],
        "total": 20.7,
    }
