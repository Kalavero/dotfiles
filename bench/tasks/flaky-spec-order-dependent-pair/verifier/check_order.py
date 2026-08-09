#!/usr/bin/env python3
"""Score the fix for the order-dependent flaky suite.

Two planted polluters, both seed-dependent:
  P1  tests/test_shipping_plugins.py registers flat-fee plugins in the
      process-wide PluginRegistry and never cleans up; the victim
      test_delivery_quote_matches_base_price then quotes 6000 instead of
      2000 (aggregate diff -- the leftover names are never printed).
  P2  tests/test_pricing.py::test_zero_rate_promo monkeypatches the tax
      table and reseeds the process-wide memoization cache in
      shop/pricing.py; monkeypatch restores the table at teardown but the
      cache keeps the promo rate 0.0, so test_standard_us_tax_rate then
      sees 0.0 instead of 0.20.

Tripwire against blanket fixes: TestStandardPluginSet in
tests/test_quote_engine.py deliberately relies on registry state shared
between the tests of the class (established once in setup_class). An
autouse per-test "clear everything" fixture in conftest therefore turns
those green tests red on every seed; only localized cleanup (polluter
files, app modules, or a snapshot/restore that preserves state) keeps the
whole suite green. pytest-randomly 3.16.0 keeps module and class blocks
contiguous (verified in its source), so this is deterministic.

Under pytest-randomly seed 8 both victims fail. Correct fixes restore the
shared state at the source (polluter file / conftest / app module) without
breaking the stateful class; weakening the victims or the stateful class,
or masking the flake (retries, sleeps, disabling randomization), is wrong.

Checks (weights sum to 1.0):
  failing_seed_green       0.25  full suite passes with seed 8, 3 runs
  other_seeds_green        0.15  suite passes under 5 more seeds (chosen so
                                 each single-polluter fix fails some of them)
  victims_unchanged        0.15  victim file AND stateful-class file both
                                 byte-identical (sha256)
  no_masking               0.15  no added sleep/retry/skip/xfail markers
  polluter_registry_fixed  0.10  shipping-plugins test, shop/registry.py,
                                 or conftest.py changed
  polluter_cache_fixed     0.10  pricing test, shop/pricing.py, or
                                 conftest.py changed
  randomization_kept       0.10  different seeds still give different orders

A blanket per-test reset fails every suite-green check and lands at 0.60;
fixing only one polluter lands around 0.50.

Writes the scalar reward to /logs/verifier/reward.txt and a per-check
breakdown to /logs/verifier/score.json.
"""

import hashlib
import json
import pathlib
import re
import subprocess

APP = pathlib.Path("/app")
LOGS = pathlib.Path("/logs/verifier")

FAIL_SEED = 8
OTHER_SEEDS = [1, 4, 5, 7, 10]
ORDER_SEEDS = (101, 202)

VICTIM = APP / "tests" / "test_checkout_baseline.py"
STATEFUL = APP / "tests" / "test_quote_engine.py"
CONFTEST = APP / "conftest.py"
P1_TEST = APP / "tests" / "test_shipping_plugins.py"
P1_APP = APP / "shop" / "registry.py"
P2_TEST = APP / "tests" / "test_pricing.py"
P2_APP = APP / "shop" / "pricing.py"

SHA256 = {
    VICTIM: "2ff24baec8e95c9db1db65feabadfb11b79aa333613828fa06366b0c5c6fd521",
    STATEFUL: "810ac4b61703c091568fd16872084b51179bba0d92c128c2d35b3c42a334f757",
    CONFTEST: "f5a5ea4cd7fe3946f06b87e3dd7771a8834f3c6010903f6768afa243ef4c40c6",
    P1_TEST: "ecafbf3fcc280d70c963eb97a800b61f2faa6a73f9bd8c31ba20a8f5f5b85a18",
    P1_APP: "ce4f1940124523c2c691483da1ecbc4b5e7eb00ae55cc05f10cc7c88669a0b7c",
    P2_TEST: "f5ef6a7c7b1a68466b406b0d0e61859124cb7b23caab94ab7a38a3b9787960f7",
    P2_APP: "1db641c456c563b37e230d06d4f6561d1e6048b02144864d1e3a9e4e920cfee7",
}

MASKING_RE = re.compile(
    r"time\.sleep|\bsleep\(|rerunfailures|pytest\.mark\.(flaky|rerun|skip|skipif|xfail)"
    r"|pytest\.(skip|xfail)\("
)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def changed(path):
    return path.exists() and sha256(path) != SHA256[path]


def run_suite(seed):
    """Run the full suite under one seed; return (passed, output)."""
    proc = subprocess.run(
        ["python", "-m", "pytest", "-q", f"--randomly-seed={seed}"],
        cwd=APP,
        capture_output=True,
        text=True,
        timeout=300,
    )
    return proc.returncode == 0, proc.stdout + proc.stderr


def test_order(seed):
    """Return the executed test order for a seed, or None if it errored."""
    proc = subprocess.run(
        ["python", "-m", "pytest", "-v", f"--randomly-seed={seed}"],
        cwd=APP,
        capture_output=True,
        text=True,
        timeout=300,
    )
    if proc.returncode not in (0, 1):
        return None
    order = []
    for line in proc.stdout.splitlines():
        m = re.match(r"^(tests/\S+::\S+) (PASSED|FAILED|ERROR|SKIPPED)", line)
        if m and m.group(1) not in order:
            order.append(m.group(1))
    return order or None


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    breakdown = {}

    # 1. The failing CI seed must now pass, three runs in a row.
    runs = []
    for i in range(3):
        ok, out = run_suite(FAIL_SEED)
        (LOGS / f"pytest_seed{FAIL_SEED}_run{i + 1}.txt").write_text(out)
        runs.append(ok)
    breakdown["failing_seed_green"] = {"weight": 0.25, "pass": all(runs), "runs": runs}

    # 2. Other fixed seeds must pass too (the fix is not seed-specific, and
    #    these seeds are chosen so a one-polluter fix still fails some).
    other = []
    for seed in OTHER_SEEDS:
        ok, out = run_suite(seed)
        (LOGS / f"pytest_seed{seed}.txt").write_text(out)
        other.append(ok)
    breakdown["other_seeds_green"] = {"weight": 0.15, "pass": all(other), "runs": dict(zip(OTHER_SEEDS, other))}

    # 3. The victim tests and the stateful class must both be untouched.
    victims_ok = all(
        p.exists() and sha256(p) == SHA256[p] for p in (VICTIM, STATEFUL)
    )
    breakdown["victims_unchanged"] = {"weight": 0.15, "pass": victims_ok}

    # 4. No masking: no added sleeps, retries, or skip/xfail markers.
    scanned = sorted(APP.glob("tests/**/*.py")) + [CONFTEST]
    hits = {}
    for path in scanned:
        if path.exists():
            found = MASKING_RE.findall(path.read_text())
            if found:
                hits[str(path)] = found
    breakdown["no_masking"] = {"weight": 0.15, "pass": not hits, "hits": hits}

    # 5. Both root causes must be fixed at the source (a shared cleanup in
    #    conftest counts for both).
    conftest_changed = changed(CONFTEST)
    breakdown["polluter_registry_fixed"] = {
        "weight": 0.10,
        "pass": changed(P1_TEST) or changed(P1_APP) or conftest_changed,
    }
    breakdown["polluter_cache_fixed"] = {
        "weight": 0.10,
        "pass": changed(P2_TEST) or changed(P2_APP) or conftest_changed,
    }

    # 6. Randomization must still be in effect (not disabled/reordered away).
    order_a = test_order(ORDER_SEEDS[0])
    order_b = test_order(ORDER_SEEDS[1])
    breakdown["randomization_kept"] = {
        "weight": 0.10,
        "pass": bool(order_a and order_b and order_a != order_b),
    }

    reward = sum(c["weight"] for c in breakdown.values() if c["pass"])
    reward = round(reward, 3)

    (LOGS / "score.json").write_text(json.dumps({"reward": reward, "checks": breakdown}, indent=2))
    (LOGS / "reward.txt").write_text(f"{reward}\n")
    print(json.dumps({"reward": reward, "checks": {k: v["pass"] for k, v in breakdown.items()}}))


if __name__ == "__main__":
    main()
