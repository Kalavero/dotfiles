#!/usr/bin/env python3
"""Score /app for the debugging-race-under-load task.

Checks (partial credit, breakdown in /logs/verifier/score.json):
  load_test_3x          0.30  tests/test_load.py passes 3 runs (0.10 each)
  no_sleep_or_retry     0.10  inventory.py gains no sleep/retry workaround
  harness_unchanged     0.15  tests/test_load.py byte-identical
  inventory_changed     0.10  inventory.py differs from the racy original
  regression_test       0.20  new test in tests/: passes now (0.08) and fails
                              against the pristine racy app (0.12)
  suite_green           0.15  full visible suite green, other original files
                              unmodified
"""

import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

APP = pathlib.Path("/app")
LOGS = pathlib.Path("/logs/verifier")
VERIFIER = pathlib.Path("/verifier")

LOAD_TEST_SHA = "44988a877d490aab7681ec16741a41d1e0184bcb079b75b60fe50742b956c144"
INVENTORY_TEST_SHA = "5850b95a2f6f55a7098009b7acc449c0d6b62ca6029321de59b09950a024789b"
CONFTEST_SHA = "8bc4d721b5357405ec7721d5d12bfcf03dee58c97eb7c1ebf0befd862b28e09d"
INVENTORY_SHA = "4bbe860fa58eda799438d00248e2506ae860f739cc0066bc74620a425321e095"

# Files restored to their racy originals when re-running new tests to
# confirm they fail without the fix.
PRISTINE_FILES = ["inventory.py", "conftest.py"]

ORIGINAL_NODE_IDS = frozenset(
    {
        "tests/test_inventory.py::test_purchase_decrements_stock",
        "tests/test_inventory.py::test_purchase_fails_when_insufficient_stock",
        "tests/test_inventory.py::test_unknown_sku_has_zero_stock",
        "tests/test_inventory.py::test_reset_inventory_restores_stock",
        "tests/test_load.py::test_no_oversell_under_load",
    }
)

NODE_ID = re.compile(r"^tests/\S+::\S+$")
SLEEP_OR_RETRY = re.compile(r"\b(sleep|retry|retries)\b", re.IGNORECASE)


def sha256(path):
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()


def run_pytest(args, cwd, timeout=300, pythonpath=None):
    env = {"PATH": "/usr/local/bin:/usr/bin:/bin", "PYTHONDONTWRITEBYTECODE": "1"}
    if pythonpath:
        env["PYTHONPATH"] = pythonpath
    proc = subprocess.run(
        [sys.executable, "-m", "pytest", "-p", "no:cacheprovider", *args],
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=timeout,
        env=env,
    )
    return proc.returncode, proc.stdout + proc.stderr


def collect_node_ids(cwd):
    rc, out = run_pytest(["tests", "--collect-only", "-q"], cwd)
    if rc != 0:
        return None
    return {line.strip() for line in out.splitlines() if NODE_ID.match(line.strip())}


def make_pristine_copy():
    """Copy /app to a temp dir and restore the racy original files."""
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="pristine_")) / "app"
    shutil.copytree(
        APP,
        tmp,
        ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "CAUSE.md"),
    )
    for rel in PRISTINE_FILES:
        shutil.copy(VERIFIER / "original" / rel, tmp / rel)
    return tmp


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    checks = {}

    # 1. The load harness must pass three consecutive runs. The pristine
    # harness copy is run against /app so editing the test gains nothing.
    runs = []
    for i in range(3):
        rc, out = run_pytest(
            ["/verifier/original/tests/test_load.py", "-q"], APP, pythonpath="/app"
        )
        runs.append(rc == 0)
    checks["load_test_3x"] = {
        "runs_passed": runs,
        "score": round(0.10 * sum(runs), 3),
    }

    # 2. No sleep/retry workarounds added to the app code.
    inventory = APP / "inventory.py"
    src = inventory.read_text() if inventory.exists() else ""
    bad = sorted({m.group(1).lower() for m in SLEEP_OR_RETRY.finditer(src)})
    checks["no_sleep_or_retry"] = {
        "offending_terms": bad,
        "score": 0.10 if not bad else 0.0,
    }

    # 3. The load harness (symptom location) byte-identical.
    harness = APP / "tests/test_load.py"
    harness_ok = harness.exists() and sha256(harness) == LOAD_TEST_SHA
    checks["harness_unchanged"] = {"unchanged": harness_ok, "score": 0.15 if harness_ok else 0.0}

    # 4. Root-cause location changed.
    changed = inventory.exists() and sha256(inventory) != INVENTORY_SHA
    checks["inventory_changed"] = {"changed": changed, "score": 0.10 if changed else 0.0}

    # 5. New regression test: passes now, fails against the racy original.
    reg = {"new_tests": [], "pass_with_fix": False, "fail_without_fix": False, "score": 0.0}
    node_ids = collect_node_ids(APP)
    if node_ids is not None:
        new_tests = sorted(node_ids - ORIGINAL_NODE_IDS)
        reg["new_tests"] = new_tests
        if new_tests:
            rc, _ = run_pytest([*new_tests, "-q"], APP)
            reg["pass_with_fix"] = rc == 0
            if rc == 0:
                reg["score"] += 0.08
            pristine = make_pristine_copy()
            rc, out = run_pytest([*new_tests, "-q"], pristine)
            reg["fail_without_fix"] = rc != 0
            reg["pristine_tail"] = out.strip().splitlines()[-1] if out.strip() else ""
            if rc != 0:
                reg["score"] += 0.12
            shutil.rmtree(pristine.parent, ignore_errors=True)
    checks["regression_test"] = reg

    # 6. Full visible suite green and the other original files unmodified.
    inv_tests_ok = (APP / "tests/test_inventory.py").exists() and (
        sha256(APP / "tests/test_inventory.py") == INVENTORY_TEST_SHA
    )
    conftest_ok = (APP / "conftest.py").exists() and sha256(APP / "conftest.py") == CONFTEST_SHA
    rc, out = run_pytest(["tests", "-q"], APP)
    green = rc == 0
    checks["suite_green"] = {
        "suite_passed": green,
        "original_tests_unmodified": inv_tests_ok,
        "conftest_unmodified": conftest_ok,
        "score": 0.15 if (green and inv_tests_ok and conftest_ok) else 0.0,
        "detail": out.strip().splitlines()[-1] if out.strip() else "",
    }

    reward = round(sum(c["score"] for c in checks.values()), 3)
    (LOGS / "score.json").write_text(
        json.dumps({"reward": reward, "checks": checks}, indent=2) + "\n"
    )
    (LOGS / "reward.txt").write_text(f"{reward}\n")
    cause = APP / "CAUSE.md"
    if cause.exists():
        shutil.copy(cause, LOGS / "CAUSE.md")
    print(json.dumps({"reward": reward, "checks": {k: v["score"] for k, v in checks.items()}}))


if __name__ == "__main__":
    main()
