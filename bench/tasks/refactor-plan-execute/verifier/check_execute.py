#!/usr/bin/env python3
"""Score the executed shipping refactor in /app.

  0.25  hidden behavior suite (/verifier/behavior_tests.py, pins the
        plan-documented behavior including both documented quirks) passes
        against the final code — proportional to tests passed
  0.15  hidden counter suite (/verifier/counter_tests.py) passes: pins the
        quotes_issued() side effect, which the provided plan does NOT
        document — all-or-nothing
  0.10  public API unchanged: the original five public functions are still
        importable from `shipping` with identical parameter lists
  0.25  the split happened per the plan: shipping/{__init__,tiers,zones,
        surcharge,calculator}.py exist and /app/shipping.py is gone
  0.05  the original visible suite (tests/test_shipping.py) is green
  0.20  characterization tests were added: >= 6 new test functions outside
        the original two-test file

Writes the scalar reward to /logs/verifier/reward.txt and a breakdown to
/logs/verifier/score.json.
"""

import json
import pathlib
import re
import shutil
import subprocess
import sys

APP = pathlib.Path("/app")
LOGS = pathlib.Path("/logs/verifier")

EXPECTED_API = {
    "quote_shipping": ["weight_kg", "zone"],
    "quote_order": ["parcels", "zone"],
    "set_fuel_surcharge": ["pct"],
    "current_fuel_surcharge": [],
    "quotes_issued": [],
}

PACKAGE_FILES = [
    "shipping/__init__.py",
    "shipping/tiers.py",
    "shipping/zones.py",
    "shipping/surcharge.py",
    "shipping/calculator.py",
]


def run_pytest(args):
    return subprocess.run(
        [sys.executable, "-m", "pytest", "-p", "no:cacheprovider", "-q", *args],
        cwd="/app",
        capture_output=True,
        text=True,
    )


def count_results(output):
    passed = sum(int(m) for m in re.findall(r"(\d+) passed", output))
    failed = sum(int(m) for m in re.findall(r"(\d+) failed", output))
    errors = sum(int(m) for m in re.findall(r"(\d+) error", output))
    return passed, failed + errors


def check_hidden_suite(src_name, weight, all_or_nothing=False):
    """Copy a hidden pytest file into /app, run it, clean up, and score
    proportionally to tests passed (or all-or-nothing when the suite pins a
    single side-effect contract)."""
    hidden_copy = APP / src_name
    shutil.copy(f"/verifier/{src_name}", hidden_copy)
    proc = run_pytest([src_name])
    hidden_copy.unlink(missing_ok=True)
    out_text = proc.stdout + proc.stderr
    (LOGS / f"{src_name.replace('.py', '')}_pytest.txt").write_text(out_text)
    shutil.copy(f"/verifier/{src_name}", LOGS / src_name)
    passed, bad = count_results(out_text)
    total = passed + bad
    if not total:
        score = 0.0
    elif all_or_nothing:
        score = weight if bad == 0 else 0.0
    else:
        score = weight * passed / total
    return {"passed": passed, "failed_or_error": bad, "score": round(score, 4)}


def check_api():
    code = (
        "import inspect, json, sys\n"
        "sys.path.insert(0, '/app')\n"
        "expected = json.loads(sys.argv[1])\n"
        "result = {}\n"
        "try:\n"
        "    import shipping\n"
        "except Exception as exc:\n"
        "    print(json.dumps({'import_error': str(exc)}))\n"
        "    raise SystemExit\n"
        "for name, params in expected.items():\n"
        "    fn = getattr(shipping, name, None)\n"
        "    ok = callable(fn) and list(inspect.signature(fn).parameters) == params\n"
        "    result[name] = ok\n"
        "print(json.dumps(result))\n"
    )
    proc = subprocess.run(
        [sys.executable, "-c", code, json.dumps(EXPECTED_API)],
        cwd="/app",
        capture_output=True,
        text=True,
    )
    (LOGS / "api_check.txt").write_text(proc.stdout + proc.stderr)
    try:
        result = json.loads(proc.stdout.strip().splitlines()[-1])
    except (ValueError, IndexError):
        result = {"import_error": "unparseable"}
    ok = sum(1 for v in result.values() if v is True)
    score = 0.10 * ok / len(EXPECTED_API)
    return {"functions": result, "score": round(score, 4)}


def check_split():
    present = {f: (APP / f).is_file() for f in PACKAGE_FILES}
    old_gone = not (APP / "shipping.py").exists()
    checks = {**present, "shipping.py_removed": old_gone}
    score = 0.25 * sum(checks.values()) / len(checks)
    return {"checks": checks, "score": round(score, 4)}


def check_visible_suite():
    proc = run_pytest(["tests/test_shipping.py"])
    (LOGS / "visible_pytest.txt").write_text(proc.stdout + proc.stderr)
    passed, bad = count_results(proc.stdout + proc.stderr)
    green = proc.returncode == 0 and passed > 0 and bad == 0
    return {"green": green, "passed": passed, "score": 0.05 if green else 0.0}


def check_characterization_tests():
    new_tests = 0
    files = []
    for path in sorted((APP / "tests").rglob("test_*.py")):
        if path == APP / "tests" / "test_shipping.py":
            continue
        n = len(re.findall(r"def test_", path.read_text()))
        if n:
            files.append({"file": str(path.relative_to(APP)), "tests": n})
            new_tests += n
    score = 0.20 * min(1.0, new_tests / 6)
    return {"new_test_functions": new_tests, "files": files, "score": round(score, 4)}


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    breakdown = {
        "hidden_behavior_suite": check_hidden_suite("behavior_tests.py", 0.25),
        "undocumented_counter_side_effect": check_hidden_suite(
            "counter_tests.py", 0.15, all_or_nothing=True
        ),
        "public_api_unchanged": check_api(),
        "split_done": check_split(),
        "visible_suite_green": check_visible_suite(),
        "characterization_tests_added": check_characterization_tests(),
    }
    reward = max(0.0, min(1.0, sum(c["score"] for c in breakdown.values())))
    breakdown["reward"] = round(reward, 3)
    (LOGS / "score.json").write_text(json.dumps(breakdown, indent=2))
    (LOGS / "reward.txt").write_text(f"{round(reward, 3)}\n")
    print(json.dumps({"reward": round(reward, 3)}))


if __name__ == "__main__":
    main()
