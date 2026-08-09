"""Pricing helpers for the shop."""

_BASE_TAX_RATES = {"US": 0.20, "DE": 0.19, "FR": 0.21}

# Rates never change while the process runs, so tax_rate_for memoizes
# process-wide.
_rate_cache = {}


def tax_rate_for(region):
    """Fractional tax rate for a region."""
    if region not in _rate_cache:
        _rate_cache[region] = _BASE_TAX_RATES[region]
    return _rate_cache[region]


def total_with_tax(cents, region):
    """Gross price in cents for a net amount in a region."""
    return round(cents * (1 + tax_rate_for(region)))


def bulk_discount(cents, quantity):
    """Ten percent off the line total for orders of ten units or more."""
    if quantity >= 10:
        return round(cents * 0.9)
    return cents
