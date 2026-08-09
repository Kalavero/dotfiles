#!/bin/bash
# Oracle: derive the behavior inventory by RUNNING /app/pricing.py (including
# the two quirks), then write a compliant refactoring plan to
# /app/refactor-pricing.md. No value in the plan is hardcoded; every pinned
# number comes from a probe executed here.
set -euo pipefail

cd /app

python3 <<'PY'
import pathlib

import pricing

# --- Phase 1: behavior inventory (run the module, probe the edges) --------
pricing.set_region("CA")

q1 = pricing.price_order([("widget", 5.35, 1)], promo="HALFOFF")
# q1["discount"]: 0.5 * 5.35 = 2.675, but _money() formats through a string
# and 2.675 is stored as 2.67499..., so it comes out as 2.67, not 2.68.
q2 = pricing.price_order([("gadget", 80.0, 1)], coupon="TENOFF")
# q2: tax is computed BEFORE the flat coupon comes off, so the $10 coupon
# does not reduce the tax; total is 80.00 + 6.80 - 10.00 = 76.80.
cap = pricing.price_order([("x", 10.0, 1)], promo="BIG60")
member = pricing.price_order([("x", 10.0, 1)], promo="WELCOME10", member=True)
log_len = len(pricing.redemption_log())
receipt = pricing.format_receipt(q2)

d1 = q1["discount"]        # 2.67  (quirk: rounds down at the 2.675 boundary)
t1 = q1["total"]           # 2.91
tax2 = q2["tax"]           # 6.8   (quirk: pre-coupon tax base)
t2 = q2["total"]           # 76.8
d_cap = cap["discount"]    # 5.0   (BIG60 capped at 50% of subtotal)
d_mem = member["discount"]  # 1.5  (0.10 + 0.05 member bonus)

try:
    pricing.set_region("XX")
    region_err = "no error"
except KeyError as exc:
    region_err = f"KeyError({exc})"

plan = f"""# Refactoring plan: split pricing.py into discount / tax / money components

## Behavior inventory (derived by running the module)

Probes executed against `/app/pricing.py` with `python3`, region `CA`:

- `price_order([("widget", 5.35, 1)], promo="HALFOFF")` -> discount is
  **{d1}**, not 2.68: `_money()` rounds through a format string and 2.675 is
  stored as 2.67499..., so the result rounds down to {d1} (total {t1}).
  Quirk — pin as-is.
- `price_order([("gadget", 80.0, 1)], coupon="TENOFF")` -> tax is computed
  on the discounted amount BEFORE the flat coupon comes off: tax {tax2} on
  80.00, then the $10 coupon, total {t2} ("{t2:.2f}"). A coupon never reduces
  the tax. Quirk — pin as-is.
- `BIG60` is capped by `MAX_DISCOUNT_PCT`: discount on 10.00 is {d_cap},
  not 6.00.
- Member bonus stacks onto the promo pct before the cap: WELCOME10 + member
  on 10.00 -> discount {d_mem} (15%).
- Every `price_order` call appends one dict to the module-level redemption
  log (observed length after probes: {log_len}).
- `format_receipt` renders the record as fixed-layout text ending with a
  `thanks, member!` line for members.
- `set_region("XX")` raises {region_err}.
- Module-level state (`_current_region`, `_promo_codes`, `_coupons`,
  `_redemptions`) is shared mutable state and part of the observable
  behavior.

Coverage: `/app/tests/test_pricing.py` has exactly two happy-path tests;
none of the behaviors above are pinned.

## Behavior contract

The refactor is done when every item below still holds, verified by tests:

- Rounding quirk: 5.35 at HALFOFF yields a discount of exactly {d1}
  (the 2.675 boundary rounds down through `_money`). Pinned as-is, never
  altered during this refactor.
- Coupon/tax quirk: a $10 `TENOFF` coupon on an 80.00 CA order leaves the
  tax at {tax2} and the total at {t2} ("{t2:.2f}") — tax is computed before
  the coupon comes off. Pinned as-is.
- Discount cap: promo discount never exceeds 50% of the subtotal; BIG60 on
  10.00 yields a {d_cap} discount.
- Member bonus: +5% stacked on the promo pct before the cap; WELCOME10 +
  member on 10.00 yields {d_mem}.
- Side effects: `redemption_log()` grows by one record per `price_order`
  call with keys region/subtotal/discount/tax/coupon/total/member;
  `format_receipt` output layout is unchanged.
- Error shapes: `set_region` with an unknown region raises
  {region_err}.
- Public API surface: `set_region`, `current_region`, `register_promo`,
  `register_coupon`, `redemption_log`, `price_order`, `bulk_quote`,
  `format_receipt`, `daily_summary` keep their names and signatures and stay
  importable from the package root.

## Steps

### Step 1: Add characterization tests pinning the current behavior

Create `tests/test_pricing_characterization.py` with one test per behavior
contract item, asserting the exact values observed above — including the
{d1} rounding result and the {t2:.2f} coupon/tax result, which look wrong
but are pinned exactly as they are. No source edits in this step.
Verify: `python3 -m pytest` — the full suite is green with the new pinning
tests included.

### Step 2 (mechanical): Turn the module into a package

Create `pricing/`; move `pricing.py` to `pricing/calculator.py` byte-for-byte;
add `pricing/__init__.py` that re-exports every public name; delete the old
file. No logic edits.
Verify: `python3 -m pytest` — full suite green.

### Step 3 (judgment): Extract the discount logic

Extract promo lookup, member stacking, and the MAX_DISCOUNT_PCT cap from
`pricing/calculator.py` into `pricing/discounts.py` behind a small function;
the calculator delegates to it. Identical arithmetic, identical cap order.
Verify: `python3 -m pytest` — full suite green.

### Step 4 (judgment): Extract the tax logic

Extract the regional rate table and the tax computation (on the discounted,
pre-coupon amount) into `pricing/tax.py`; the calculator delegates.
Verify: `python3 -m pytest` — full suite green.

### Step 5 (judgment): Extract the rounding helper and receipt rendering

Extract `_money` into `pricing/money.py` and `format_receipt` into
`pricing/receipt.py`; the calculator delegates to both. The string-format
rounding semantics of `_money` stay byte-identical.
Verify: `python3 -m pytest` — full suite green.

### Step 6 (mechanical): Organize the test tree

Move the new pinning tests into `tests/characterization/` and the original
happy-path tests into `tests/unit/`; no assertion edits.
Verify: `python3 -m pytest` — full suite green.

### Step 7: Final contract walk

Walk every behavior contract item, run the suite one last time, and state
how each item was verified (which test pins it).
Verify: `python3 -m pytest` — full suite green; contract checklist complete.
"""

pathlib.Path("/app/refactor-pricing.md").write_text(plan)
print("wrote /app/refactor-pricing.md")
print(f"pinned rounding quirk: discount={d1} total={t1}")
print(f"pinned coupon/tax quirk: tax={tax2} total={t2}")
PY
