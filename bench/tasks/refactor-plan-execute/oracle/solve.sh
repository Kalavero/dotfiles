#!/bin/bash
# Oracle: execute /app/tasks/refactor-shipping.md as written.
# Step 1: characterization tests pinning current behavior (suite green).
# Step 2: module -> package (byte-for-byte move, re-export shim).
# Steps 3-5: extract tiers, zones, surcharge/finalizer (suite green).
# Step 6: final contract walk (full suite green).
set -euo pipefail

cd /app

# --- Step 1: characterization tests ----------------------------------------
mkdir -p tests
cat > tests/test_shipping_characterization.py <<'EOF'
"""Characterization tests: pin the current behavior of shipping.py exactly,
including its quirks (base-only fuel surcharge, cent truncation, inclusive
tier boundaries, per-started-kg overweight billing). Values were produced by
running the original module. They look wrong in places; that is intended.
"""

import pytest

import shipping


@pytest.fixture(autouse=True)
def reset_surcharge():
    shipping.set_fuel_surcharge(0.07)
    yield
    shipping.set_fuel_surcharge(0.07)


def test_surcharge_on_base_only_and_truncation():
    assert shipping.quote_shipping(3, "national") == 12.52


def test_local_light_parcel():
    assert shipping.quote_shipping(0.5, "local") == 5.24


def test_tier_boundary_inclusive_and_truncation():
    assert shipping.quote_shipping(1.0, "local") == 5.24
    assert shipping.quote_shipping(1.0001, "local") == 8.02


def test_overweight_per_started_kg():
    assert shipping.quote_shipping(23.2, "remote") == 50.34
    assert shipping.quote_shipping(20, "regional") == 26.13
    assert shipping.quote_shipping(20.01, "local") == 22.09


def test_surcharge_change_affects_base_only():
    shipping.set_fuel_surcharge(0.10)
    assert shipping.quote_shipping(3, "national") == 12.75


def test_unknown_zone_raises_keyerror():
    with pytest.raises(KeyError):
        shipping.quote_shipping(1, "moon")


def test_quote_counter_and_order_shape():
    before = shipping.quotes_issued()
    result = shipping.quote_order([3, 0.5], "national")
    assert shipping.quotes_issued() == before + 2
    assert result == {
        "zone": "national",
        "parcels": 2,
        "quotes": [12.52, 8.18],
        "total": 20.7,
    }
EOF

python3 -m pytest -p no:cacheprovider -q

# --- Step 2 (mechanical): module -> package --------------------------------
mkdir -p shipping
cp shipping.py shipping/calculator.py
rm shipping.py

# --- Steps 3-5 (judgment): extract tiers, zones, surcharge -----------------
cat > shipping/tiers.py <<'EOF'
"""Weight tiers and base rates."""

import math

WEIGHT_TIERS = [
    (1.0, 4.90),
    (5.0, 7.50),
    (10.0, 12.25),
    (20.0, 19.80),
]
OVERWEIGHT_BASE = 19.80
OVERWEIGHT_PER_KG = 0.85  # per started kg above 20


def _tier_base(weight_kg):
    """Base rate for a parcel of the given weight."""
    for limit, rate in WEIGHT_TIERS:
        if weight_kg <= limit:
            return rate
    extra_kg = math.ceil(weight_kg - 20.0)
    return OVERWEIGHT_BASE + OVERWEIGHT_PER_KG * extra_kg
EOF

cat > shipping/zones.py <<'EOF'
"""Destination zone multipliers. Plain dict: unknown zones raise KeyError."""

ZONE_MULTIPLIERS = {
    "local": 1.0,
    "regional": 1.25,
    "national": 1.6,
    "remote": 2.1,
}
EOF

cat > shipping/surcharge.py <<'EOF'
"""Fuel surcharge state and the cent finalizer."""

_fuel_surcharge_pct = 0.07


def set_fuel_surcharge(pct):
    """Set the fuel surcharge fraction (e.g. 0.07) for subsequent quotes."""
    global _fuel_surcharge_pct
    _fuel_surcharge_pct = pct


def current_fuel_surcharge():
    return _fuel_surcharge_pct


def _surcharge_amount(base):
    """Surcharge for a base rate; applies to the base only, never the
    zone-multiplied amount."""
    return base * _fuel_surcharge_pct


def _finalize(amount):
    """Cut a computed amount down to cents (truncate, not round)."""
    return int(amount * 100) / 100
EOF

cat > shipping/calculator.py <<'EOF'
"""Quote orchestration and the quote counter."""

from . import surcharge, tiers, zones

_quotes_issued = 0


def quotes_issued():
    """How many parcel quotes have been issued so far."""
    return _quotes_issued


def quote_shipping(weight_kg, zone):
    """Quote one parcel. Unknown zones raise KeyError."""
    global _quotes_issued
    _quotes_issued += 1
    base = tiers._tier_base(weight_kg)
    mult = zones.ZONE_MULTIPLIERS[zone]
    # fuel surcharge applies to the base tier rate only, not the zone uplift
    total = base * mult + surcharge._surcharge_amount(base)
    return surcharge._finalize(total)


def quote_order(parcels, zone):
    """Quote a multi-parcel order.

    parcels: list of weights in kg. Every parcel is quoted individually;
    the order total is the finalized sum of the parcel quotes.
    """
    quotes = [quote_shipping(w, zone) for w in parcels]
    return {
        "zone": zone,
        "parcels": len(parcels),
        "quotes": quotes,
        "total": surcharge._finalize(sum(quotes)),
    }
EOF

cat > shipping/__init__.py <<'EOF'
"""Shipping cost calculator: public API re-exports."""

from shipping.calculator import quote_order, quote_shipping, quotes_issued
from shipping.surcharge import current_fuel_surcharge, set_fuel_surcharge

__all__ = [
    "quote_shipping",
    "quote_order",
    "quotes_issued",
    "set_fuel_surcharge",
    "current_fuel_surcharge",
]
EOF

# --- Step 6: final contract walk -------------------------------------------
python3 -m pytest -p no:cacheprovider -q
echo "oracle done: package split complete, full suite green"
