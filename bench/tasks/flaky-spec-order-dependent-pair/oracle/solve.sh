#!/bin/bash
# Oracle: characterize the flake (isolation vs seeded suite), localize both
# polluters by computation (pairwise order probes), fix each root cause in
# its polluter file, then re-run the failing seed plus others to confirm.
set -euo pipefail

cd /app

echo "== step 1: reproduce with the failing CI seed =="
python -m pytest -q --randomly-seed=8 > /tmp/seed8.log 2>&1 || true
cat /tmp/seed8.log
grep -q "FAILED tests/test_checkout_baseline.py::test_delivery_quote_matches_base_price" /tmp/seed8.log
grep -q "FAILED tests/test_checkout_baseline.py::test_standard_us_tax_rate" /tmp/seed8.log
echo "reproduced: both baseline tests fail under seed 8"

echo "== step 2: victims pass in isolation under the same seed =="
python -m pytest -q --randomly-seed=8 tests/test_checkout_baseline.py

echo "== step 3: pairwise order probes (randomization off, explicit order) =="
# Probe 1: which file inflates the delivery quote?
python -m pytest -q -p no:randomly tests/test_shipping_plugins.py tests/test_checkout_baseline.py::test_delivery_quote_matches_base_price > /tmp/pair1.log 2>&1 || true
grep -q "1 failed" /tmp/pair1.log && echo "P1 confirmed: test_shipping_plugins.py breaks the quote baseline"
# Probe 2: which test zeroes the US tax rate?
python -m pytest -q -p no:randomly tests/test_pricing.py::test_zero_rate_promo tests/test_checkout_baseline.py::test_standard_us_tax_rate > /tmp/pair2.log 2>&1 || true
grep -q "1 failed" /tmp/pair2.log && echo "P2 confirmed: test_zero_rate_promo breaks the tax-rate baseline"
python -m pytest -q -p no:randomly tests/test_checkout_baseline.py tests/test_shipping_plugins.py > /dev/null
python -m pytest -q -p no:randomly tests/test_checkout_baseline.py::test_standard_us_tax_rate tests/test_pricing.py::test_zero_rate_promo > /dev/null
echo "reversed orders pass: both failures are order-dependent leakage"

echo "== step 4: confirm the leak mechanisms by computation =="
python3 <<'PY'
from shop import pricing
from shop.registry import PluginRegistry
from shop.shipping import delivery_quote_cents

# P1: plugins registered by the shipping tests persist in the process-wide
# registry and inflate delivery quotes.
assert delivery_quote_cents(2000) == 2000
PluginRegistry.register("express", lambda base: 1000)
PluginRegistry.register("fragile", lambda base: 500)
PluginRegistry.register("overnight", lambda base: 2500)
assert delivery_quote_cents(2000) == 6000, delivery_quote_cents(2000)
PluginRegistry.clear()
print("P1 mechanism: leftover registry entries add 4000 to the quote")

# P2: monkeypatch restores the table at teardown, but the promo rate stays
# memoized in the process-wide cache.
pricing._BASE_TAX_RATES["US"] = 0.0      # what monkeypatch.setitem did
pricing._rate_cache.clear()              # what the promo test did
assert pricing.tax_rate_for("US") == 0.0
pricing._BASE_TAX_RATES["US"] = 0.20     # what monkeypatch undid at teardown
assert pricing.tax_rate_for("US") == 0.0  # cache still serves the promo rate
pricing._rate_cache.clear()
assert pricing.tax_rate_for("US") == 0.20
print("P2 mechanism: memoized promo rate survives monkeypatch teardown")
PY

echo "== step 5: fix both root causes at their source =="
python3 <<'PY'
import pathlib

# P1: the shipping-plugin tests mutate the process-wide PluginRegistry and
# never restore it -- clean up after each of them.
p1 = pathlib.Path("/app/tests/test_shipping_plugins.py")
src = p1.read_text()
assert "class TestShippingPlugins" in src and "PluginRegistry.register" in src
assert "teardown" not in src
assert src.endswith("\n")
src += (
    "\n"
    "    def teardown_method(self):\n"
    "        # These tests mutate the process-wide PluginRegistry; restore it\n"
    "        # so no state leaks into tests that run after this class.\n"
    "        PluginRegistry.clear()\n"
)
p1.write_text(src)
print("added teardown_method registry cleanup to", p1)

# P2: the promo test reseeds the memoization cache but never clears it
# afterwards, so the promo rate outlives the monkeypatch -- clear the cache
# after every test in the module.
p2 = pathlib.Path("/app/tests/test_pricing.py")
src = p2.read_text()
assert "test_zero_rate_promo" in src and "_rate_cache" in src
assert "teardown_function" not in src
assert src.endswith("\n")
src += (
    "\n"
    "\n"
    "def teardown_function(function):\n"
    "    # tax_rate_for memoizes process-wide; tests that seed _rate_cache\n"
    "    # must not leak cached rates into tests that run later.\n"
    "    pricing._rate_cache.clear()\n"
)
p2.write_text(src)
print("added teardown_function cache cleanup to", p2)
PY

echo "== step 6: re-run the failing seed and others to confirm =="
for seed in 8 8 8 1 4 5 7 10 18 24 32; do
  python -m pytest -q --randomly-seed=$seed >/dev/null
  echo "seed $seed: PASS"
done

cat > /app/flake_report.md <<'EOF'
# Flake report: tests/test_checkout_baseline.py

## Symptom

`test_delivery_quote_matches_base_price` and `test_standard_us_tax_rate`
fail only for some pytest-randomly seeds (both under `--randomly-seed=8`)
and pass in isolation.

## Root causes (two independent order-dependent leaks)

1. `TestShippingPlugins` (tests/test_shipping_plugins.py) registers
   flat-fee plugins in the process-wide `PluginRegistry` and never cleans
   up. When any of them run first, `delivery_quote_cents` sums the leftover
   fees and the quote baseline comes out at 6000 instead of 2000.
2. `test_zero_rate_promo` (tests/test_pricing.py) monkeypatches
   `_BASE_TAX_RATES` and reseeds the process-wide memoization cache
   `_rate_cache`. monkeypatch restores the table at teardown, but the
   cached promo rate (0.0) survives, so the US tax-rate baseline reads 0.0
   instead of 0.20 whenever the promo test ran first.

Both confirmed with pairwise probes (`-p no:randomly`, explicit order):
polluter-first fails, victim-first passes.

## Why not a blanket reset

A conftest fixture that clears the registry/cache around every test would
silence both leaks, but `TestStandardPluginSet`
(tests/test_quote_engine.py) deliberately shares its registered plugin set
between the tests of the class (established once in `setup_class`), so a
per-test wipe turns those green tests red. The cleanup has to be localized
to the polluters.

## Fixes

- `TestShippingPlugins` gained a `teardown_method` calling
  `PluginRegistry.clear()`.
- tests/test_pricing.py gained a `teardown_function` clearing
  `pricing._rate_cache`.

The victim tests and the stateful quote-engine class are untouched; no
retries or sleeps were added. Re-ran seed 8 three times plus seeds 1, 4,
5, 7, 10, 18, 24, 32: all green.
EOF

echo "oracle done"
