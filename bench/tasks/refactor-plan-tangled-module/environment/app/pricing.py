"""Storefront pricing engine.

Computes order totals: promo-code discounts, member pricing, regional sales
tax, flat coupons, and cash rounding. Everything lives in this one module;
it grew organically since 2019 and nobody wants to touch it.
"""

import json
import os

# ---------------------------------------------------------------------------
# Global configuration and state
# ---------------------------------------------------------------------------

REGION_TAX_RATES = {
    "CA": 0.085,
    "NY": 0.08875,
    "TX": 0.0625,
    "OR": 0.0,
}

_current_region = "CA"

_promo_codes = {
    "WELCOME10": 0.10,
    "HALFOFF": 0.50,
    "BIG60": 0.60,
}

_coupons = {
    "TENOFF": 10.0,
    "FIVE": 5.0,
}

MAX_DISCOUNT_PCT = 0.50  # promo + member discount never exceeds 50% of subtotal

_redemptions = []  # audit trail: one dict appended per priced order

AUDIT_FILE = os.environ.get("PRICING_AUDIT_FILE", "")


def set_region(region):
    """Set the tax region used by subsequent price_order calls."""
    global _current_region
    if region not in REGION_TAX_RATES:
        raise KeyError(region)
    _current_region = region


def current_region():
    return _current_region


def register_promo(code, pct):
    """Register or overwrite a promo code (fraction off, e.g. 0.10)."""
    _promo_codes[code] = pct


def register_coupon(code, amount):
    """Register or overwrite a flat coupon (absolute amount off)."""
    _coupons[code] = amount


def redemption_log():
    """Return a copy of the audit trail of priced orders."""
    return list(_redemptions)


def _money(x):
    """Round to cents by formatting through a string and parsing back."""
    return float(f"{x:.2f}")


def price_order(items, promo=None, coupon=None, member=False):
    """Price an order.

    items: list of (name, unit_price, qty) tuples.
    Returns a dict with subtotal, discount, tax, coupon, total, and the
    region the order was priced under. Every call appends to the audit log.
    """
    subtotal = 0.0
    for name, unit_price, qty in items:
        line = unit_price * qty
        subtotal += line
    subtotal = _money(subtotal)

    # --- discount: promo code + member bonus, capped -----------------------
    pct = 0.0
    if promo:
        pct = _promo_codes.get(promo, 0.0)
    if member:
        pct = pct + 0.05
    if pct > MAX_DISCOUNT_PCT:
        pct = MAX_DISCOUNT_PCT
    discount = _money(subtotal * pct)

    # --- tax: on the discounted amount, BEFORE any flat coupon -------------
    rate = REGION_TAX_RATES[_current_region]
    taxable = subtotal - discount
    tax = _money(taxable * rate)

    # --- coupon: flat amount, comes off after tax --------------------------
    coupon_off = 0.0
    if coupon:
        coupon_off = _coupons.get(coupon, 0.0)

    total = _money(subtotal - discount + tax - coupon_off)

    record = {
        "region": _current_region,
        "subtotal": subtotal,
        "discount": discount,
        "tax": tax,
        "coupon": coupon_off,
        "total": total,
        "member": bool(member),
    }
    _redemptions.append(record)
    if AUDIT_FILE:
        with open(AUDIT_FILE, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(record) + "\n")
    return record


def bulk_quote(orders):
    """Price several orders at once.

    orders: list of kwargs dicts for price_order, e.g.
        [{"items": [("book", 20.0, 2)], "promo": "WELCOME10"}, ...]
    Returns {"orders": [...], "count": n, "grand_total": x}.
    """
    records = []
    grand = 0.0
    for order in orders:
        rec = price_order(**order)
        records.append(rec)
        grand += rec["total"]
    return {
        "orders": records,
        "count": len(records),
        "grand_total": _money(grand),
    }


def format_receipt(record):
    """Render a priced-order record as a plain-text receipt."""
    lines = []
    lines.append("=== RECEIPT ===")
    lines.append("region: " + record["region"])
    lines.append("subtotal: %.2f" % record["subtotal"])
    if record["discount"]:
        lines.append("discount: -%.2f" % record["discount"])
    lines.append("tax: %.2f" % record["tax"])
    if record["coupon"]:
        lines.append("coupon: -%.2f" % record["coupon"])
    lines.append("total: %.2f" % record["total"])
    if record["member"]:
        lines.append("thanks, member!")
    return "\n".join(lines)


def daily_summary():
    """Summarize the audit trail: count and revenue per region."""
    summary = {}
    for rec in _redemptions:
        region = rec["region"]
        if region not in summary:
            summary[region] = {"orders": 0, "revenue": 0.0}
        summary[region]["orders"] += 1
        summary[region]["revenue"] = _money(
            summary[region]["revenue"] + rec["total"]
        )
    return summary
