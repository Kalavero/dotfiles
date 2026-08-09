#!/usr/bin/env python3
"""Score the fix for the time-bomb flake.

The planted bug: tests/test_billing.py pins RECENT_SIGNUP to a hard-coded
date (2026-07-05) that was inside the 30-day trial window when the test was
written but has since aged out, so the two "recent signup" tests now fail
deterministically. The correct fix freezes time in the tests (freezegun /
freeze_time / monkeypatched datetime). Bumping the hard-coded date re-bombs
later; sleeps/retries mask the flake; changing billing.py breaks the
business logic.

Checks (weights sum to 1.0):
  suite_green       0.50  suite passes AND the two time-pinned tests still
                          exist and pass (guards against deleting them)
  hidden_contract   0.30  hidden tests drive the app functions with
                          controlled "now" values: business logic unchanged
  freeze_machinery  0.20  the fixed tests freeze time (freeze_time /
                          freezegun / monkeypatched datetime)

Caps (applied after the weighted sum, per task spec):
  - sleep/retry markers found in the tests      -> reward capped at 0.3
  - no time-freezing machinery in the tests     -> reward capped at 0.5
    (e.g. suite green only because the hard-coded date was bumped)

Writes the scalar reward to /logs/verifier/reward.txt and a per-check
breakdown to /logs/verifier/score.json.
"""

import json
import pathlib
import re
import shutil
import subprocess

APP = pathlib.Path("/app")
LOGS = pathlib.Path("/logs/verifier")
HIDDEN_SRC = pathlib.Path("/verifier/hidden")
HIDDEN_DST = pathlib.Path("/tmp/hidden_contract")

TIME_PINNED_TESTS = [
    "test_recent_signup_has_active_trial",
    "test_recent_signup_has_days_left",
]

FREEZE_RE = re.compile(r"freeze_time|freezegun", re.IGNORECASE)
MONKEYPATCH_DT_RE = re.compile(r"monkeypatch", re.IGNORECASE)
DATETIME_RE = re.compile(r"datetime")
MASKING_RE = re.compile(
    r"time\.sleep|\bsleep\(|rerunfailures|pytest\.mark\.(flaky|rerun)"
)
HARDCODED_DATE_RE = re.compile(r"2026,\s*7,\s*5|2026-07-05")


def run(cmd, **kw):
    return subprocess.run(
        cmd, cwd=APP, capture_output=True, text=True, timeout=300, **kw
    )


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    breakdown = {}

    # 1. Suite green now, with the time-pinned tests still present + passing.
    proc = run(["python", "-m", "pytest", "-v"])
    out = proc.stdout + proc.stderr
    (LOGS / "pytest_suite.txt").write_text(out)
    suite_green = proc.returncode == 0
    pinned = {
        name: bool(re.search(rf"{name} PASSED", out)) for name in TIME_PINNED_TESTS
    }
    breakdown["suite_green"] = {
        "weight": 0.50,
        "pass": suite_green and all(pinned.values()),
        "suite_exit_ok": suite_green,
        "time_pinned_tests_passing": pinned,
    }

    # 2. Hidden contract tests: business logic unchanged under controlled now.
    HIDDEN_DST.mkdir(parents=True, exist_ok=True)
    for f in HIDDEN_SRC.glob("*.py"):
        shutil.copy(f, HIDDEN_DST / f.name)
    env = {"PYTHONPATH": str(APP), "PATH": "/usr/local/bin:/usr/bin:/bin"}
    hidden = run(["python", "-m", "pytest", "-q", str(HIDDEN_DST)], env=env)
    (LOGS / "pytest_hidden.txt").write_text(hidden.stdout + hidden.stderr)
    breakdown["hidden_contract"] = {"weight": 0.30, "pass": hidden.returncode == 0}

    # 3. Freeze machinery in the fixed tests.
    test_sources = {
        str(p): p.read_text() for p in sorted(APP.glob("tests/**/*.py"))
    }
    freeze_hits = []
    for name, src in test_sources.items():
        if FREEZE_RE.search(src) or (
            MONKEYPATCH_DT_RE.search(src) and DATETIME_RE.search(src)
        ):
            freeze_hits.append(name)
    freeze_ok = bool(freeze_hits)
    breakdown["freeze_machinery"] = {
        "weight": 0.20,
        "pass": freeze_ok,
        "files": freeze_hits,
    }

    reward = sum(c["weight"] for c in breakdown.values() if c["pass"])

    # Caps.
    masking_hits = {
        name: MASKING_RE.findall(src)
        for name, src in test_sources.items()
        if MASKING_RE.findall(src)
    }
    capped = None
    if masking_hits:
        reward = min(reward, 0.3)
        capped = "sleep_or_retry_present:0.3"
    elif not freeze_ok:
        reward = min(reward, 0.5)
        capped = "no_freeze_machinery:0.5"

    reward = round(reward, 3)
    (LOGS / "score.json").write_text(
        json.dumps(
            {
                "reward": reward,
                "checks": breakdown,
                "masking_hits": masking_hits,
                "hardcoded_date_still_present": any(
                    HARDCODED_DATE_RE.search(src) for src in test_sources.values()
                ),
                "cap_applied": capped,
            },
            indent=2,
        )
    )
    (LOGS / "reward.txt").write_text(f"{reward}\n")
    print(
        json.dumps(
            {
                "reward": reward,
                "checks": {k: v["pass"] for k, v in breakdown.items()},
                "cap_applied": capped,
            }
        )
    )


if __name__ == "__main__":
    main()
