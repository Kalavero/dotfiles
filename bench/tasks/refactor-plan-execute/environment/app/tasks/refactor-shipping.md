# Refactoring plan: split shipping.py into a shipping package

Goal: turn `/app/shipping.py` into a `shipping/` package with one module per
concern — `shipping/tiers.py` (weight tiers), `shipping/zones.py` (zone
multipliers), `shipping/surcharge.py` (fuel surcharge state and the cent
finalizer), `shipping/calculator.py` (quote orchestration and the quote
counter) — without any observable behavior changing.

## Behavior inventory (derived by running the module)

Probes executed against `/app/shipping.py` with `python3`:

- `quote_shipping(3, "national")` -> **12.52**: base 7.50, zone uplift to
  12.00, fuel surcharge 0.525 applied to the BASE ONLY (not the
  zone-multiplied amount) gives 12.525, and `_finalize` TRUNCATES to cents,
  so 12.525 becomes 12.52, not 12.53. Two quirks — pin both as-is.
- `quote_shipping(1.0001, "local")` -> **8.02**: tier boundary is inclusive
  (`<=`), so 1.0 kg is the 4.90 tier but anything above it is the 7.50 tier;
  8.025 truncates to 8.02.
- `quote_shipping(23.2, "remote")` -> **50.34**: overweight bills per
  STARTED kg (`math.ceil`), so 3.2 extra kg bills as 4.
- `quote_shipping(20, "regional")` -> **26.13**; `quote_shipping(20.01,
  "local")` -> **22.09**.
- `set_fuel_surcharge(0.10)` then `quote_shipping(3, "national")` ->
  **12.75** (12.00 + 0.75; if the surcharge applied after the zone uplift
  this would be 13.20 — it does not).
- `quote_shipping(1, "moon")` raises `KeyError('moon')`.
- `quote_order([3, 0.5], "national")` -> `{'zone': 'national', 'parcels': 2,
  'quotes': [12.52, 8.18], 'total': 20.7}`.

Coverage: `/app/tests/test_shipping.py` has exactly two happy-path tests;
none of the behaviors above are pinned.

## Behavior contract

The refactor is done when every item below still holds, verified by tests:

- Fuel surcharge applies to the base tier rate only: 3 kg national ->
  12.52; with surcharge 0.10 -> 12.75.
- `_finalize` truncates toward zero at cents: 8.025 -> 8.02, 12.525 ->
  12.52.
- Tier boundaries are inclusive; overweight bills per started kg:
  20 kg regional -> 26.13; 20.01 kg local -> 22.09; 23.2 kg remote -> 50.34.
- Unknown zone raises `KeyError`.
- `quote_order` result shape and values: keys zone/parcels/quotes/total,
  total is the finalized sum of finalized parcel quotes.
- Public API surface: `quote_shipping(weight_kg, zone)`,
  `quote_order(parcels, zone)`, `set_fuel_surcharge(pct)`,
  `current_fuel_surcharge()`, `quotes_issued()` keep their names and
  signatures and stay importable from `shipping`.

## Steps

### Step 1: Add characterization tests pinning the current behavior

Create `tests/test_shipping_characterization.py` with one test per behavior
contract item, asserting the exact values above — including the 12.52 and
8.02 truncation results and the base-only fuel surcharge, which look wrong
but are pinned exactly as they are. Reset the surcharge to 0.07 around tests
that change it. No source edits in this step.
Verify: `python3 -m pytest` — the full suite is green with the new tests.

### Step 2 (mechanical): Turn the module into a package

Create `shipping/`; move `shipping.py` to `shipping/calculator.py`
byte-for-byte; add `shipping/__init__.py` that re-exports every public name;
delete the old `shipping.py`. No logic edits.
Verify: `python3 -m pytest` — full suite green.

### Step 3 (judgment): Extract the weight tiers

Extract `WEIGHT_TIERS`, `OVERWEIGHT_BASE`, `OVERWEIGHT_PER_KG`, and
`_tier_base` into `shipping/tiers.py`; the calculator imports them.
Identical arithmetic, including the `math.ceil` overweight rule.
Verify: `python3 -m pytest` — full suite green.

### Step 4 (judgment): Extract the zone table

Extract `ZONE_MULTIPLIERS` into `shipping/zones.py`; the calculator imports
it. The lookup stays a plain dict access so unknown zones keep raising
`KeyError`.
Verify: `python3 -m pytest` — full suite green.

### Step 5 (judgment): Extract the fuel surcharge and the finalizer

Extract the surcharge state (`set_fuel_surcharge`, `current_fuel_surcharge`,
`_fuel_surcharge_pct`) and `_finalize` into `shipping/surcharge.py`; the
calculator delegates. The surcharge still applies to the base rate only, and
`_finalize` still truncates.
Verify: `python3 -m pytest` — full suite green.

### Step 6: Final contract walk

Walk every behavior contract item, run the suite one last time, and state
how each item was verified (which test pins it).
Verify: `python3 -m pytest` — full suite green; contract checklist complete.
