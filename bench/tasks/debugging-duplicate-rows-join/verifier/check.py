#!/usr/bin/env python3
"""Score /app for the debugging-duplicate-rows-join task.

Checks (partial credit, breakdown in /logs/verifier/score.json):
  hidden_behavior            0.35  hidden test: unique users AND all roles
  presentation_unchanged     0.15  render.py and seed.py byte-identical
  queries_changed            0.10  queries.py differs from the broken original
  regression_test            0.25  new test in tests/: passes now (0.10) and
                                   fails against the pristine broken app (0.15)
  suite_green                0.15  full visible suite green, original test
                                   files unmodified
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

RENDER_SHA = "a064fc93c5cafdceac80addc99e9fbea36bac7dfebc7ccff96f4782ba8baa381"
SEED_SHA = "434010bac76d6d2f17d8a98da05ae1c8e2dad96dcecdb21c001983f001556363"
QUERIES_SHA = "351b9531d2dc7ff95ec7e2905c61fb9d3d437dce37f1fd3c4c78ad4064254922"
TEST_USERS_SHA = "322a67b7f1e7c80f5f177aea154a4d7da13257972e5020a4481edb4ca17331f9"
CONFTEST_SHA = "949a444bfcbbf739c9b97c111b83a30f15b0ff6cb4a5ad8088dd8e60fa127d1d"

# Files restored to their broken originals when re-running new tests to
# confirm they fail without the fix.
PRISTINE_FILES = ["queries.py", "render.py", "seed.py", "conftest.py"]

ORIGINAL_NODE_IDS = frozenset(
    {
        "tests/test_users.py::test_seed_creates_all_users",
        "tests/test_users.py::test_render_includes_every_user",
        "tests/test_users.py::test_user_with_single_role_renders_once",
        "tests/test_users.py::test_render_lists_each_user_exactly_once",
    }
)

NODE_ID = re.compile(r"^tests/\S+::\S+$")


def sha256(path):
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()


def run_pytest(args, cwd, timeout=300):
    env = {"PATH": "/usr/local/bin:/usr/bin:/bin", "PYTHONDONTWRITEBYTECODE": "1"}
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
    """Copy /app to a temp dir and restore the broken original files."""
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="pristine_")) / "app"
    shutil.copytree(
        APP,
        tmp,
        ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "app.db", "CAUSE.md"),
    )
    for rel in PRISTINE_FILES:
        shutil.copy(VERIFIER / "original" / rel, tmp / rel)
    return tmp


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    checks = {}

    # 1. Hidden behavior test: unique users, all roles preserved.
    rc, out = run_pytest(["/verifier/hidden_test.py", "-q"], APP)
    checks["hidden_behavior"] = {
        "passed": rc == 0,
        "score": 0.35 if rc == 0 else 0.0,
        "detail": out.strip().splitlines()[-1] if out.strip() else "",
    }

    # 2. Symptom location (presentation layer + seed data) unchanged.
    render_ok = (APP / "render.py").exists() and sha256(APP / "render.py") == RENDER_SHA
    seed_ok = (APP / "seed.py").exists() and sha256(APP / "seed.py") == SEED_SHA
    checks["presentation_unchanged"] = {
        "render_py_unchanged": render_ok,
        "seed_py_unchanged": seed_ok,
        "score": 0.15 if (render_ok and seed_ok) else 0.0,
    }

    # 3. Root-cause location changed.
    queries = APP / "queries.py"
    changed = queries.exists() and sha256(queries) != QUERIES_SHA
    checks["queries_changed"] = {"changed": changed, "score": 0.10 if changed else 0.0}

    # 4. New regression test: passes now, fails against the broken original.
    reg = {"new_tests": [], "pass_with_fix": False, "fail_without_fix": False, "score": 0.0}
    node_ids = collect_node_ids(APP)
    if node_ids is not None:
        new_tests = sorted(node_ids - ORIGINAL_NODE_IDS)
        reg["new_tests"] = new_tests
        if new_tests:
            rc, _ = run_pytest([*new_tests, "-q"], APP)
            reg["pass_with_fix"] = rc == 0
            if rc == 0:
                reg["score"] += 0.10
            pristine = make_pristine_copy()
            rc, out = run_pytest([*new_tests, "-q"], pristine)
            reg["fail_without_fix"] = rc != 0
            reg["pristine_tail"] = out.strip().splitlines()[-1] if out.strip() else ""
            if rc != 0:
                reg["score"] += 0.15
            shutil.rmtree(pristine.parent, ignore_errors=True)
    checks["regression_test"] = reg

    # 5. Full visible suite green and original test files unmodified.
    tests_ok = (APP / "tests/test_users.py").exists() and (
        sha256(APP / "tests/test_users.py") == TEST_USERS_SHA
    )
    conftest_ok = (APP / "conftest.py").exists() and sha256(APP / "conftest.py") == CONFTEST_SHA
    rc, out = run_pytest(["tests", "-q"], APP)
    green = rc == 0
    checks["suite_green"] = {
        "suite_passed": green,
        "original_tests_unmodified": tests_ok,
        "conftest_unmodified": conftest_ok,
        "score": 0.15 if (green and tests_ok and conftest_ok) else 0.0,
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
