"""Shipping cost calculator.

Weight tiers, destination zones, and a fuel surcharge, all in one module
with module-level state. Grown organically; nobody wants to touch it.
"""

import math

# ---------------------------------------------------------------------------
# Rate tables and global state
# ---------------------------------------------------------------------------

WEIGHT_TIERS = [
    (1.0, 4.90),
    (5.0, 7.50),
    (10.0, 12.25),
    (20.0, 19.80),
]
OVERWEIGHT_BASE = 19.80
OVERWEIGHT_PER_KG = 0.85  # per started kg above 20

ZONE_MULTIPLIERS = {
    "local": 1.0,
    "regional": 1.25,
    "national": 1.6,
    "remote": 2.1,
}

_fuel_surcharge_pct = 0.07
_quotes_issued = 0


def set_fuel_surcharge(pct):
    """Set the fuel surcharge fraction (e.g. 0.07) for subsequent quotes."""
    global _fuel_surcharge_pct
    _fuel_surcharge_pct = pct


def current_fuel_surcharge():
    return _fuel_surcharge_pct


def quotes_issued():
    """How many parcel quotes have been issued so far."""
    return _quotes_issued


def _tier_base(weight_kg):
    """Base rate for a parcel of the given weight."""
    for limit, rate in WEIGHT_TIERS:
        if weight_kg <= limit:
            return rate
    extra_kg = math.ceil(weight_kg - 20.0)
    return OVERWEIGHT_BASE + OVERWEIGHT_PER_KG * extra_kg


def _finalize(amount):
    """Cut a computed amount down to cents."""
    return int(amount * 100) / 100


def quote_shipping(weight_kg, zone):
    """Quote one parcel. Unknown zones raise KeyError."""
    global _quotes_issued
    _quotes_issued += 1
    base = _tier_base(weight_kg)
    mult = ZONE_MULTIPLIERS[zone]
    # fuel surcharge applies to the base tier rate only, not the zone uplift
    total = base * mult + base * _fuel_surcharge_pct
    return _finalize(total)


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
        "total": _finalize(sum(quotes)),
    }
