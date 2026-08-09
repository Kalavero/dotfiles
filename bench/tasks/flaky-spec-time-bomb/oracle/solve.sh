#!/bin/bash
# Oracle: reproduce the time-bomb failure, derive the boundary by
# computation, freeze time in the tests with freezegun, then re-run.
set -euo pipefail

cd /app

echo "== step 1: reproduce =="
python -m pytest -q > /tmp/before.log 2>&1 || true
cat /tmp/before.log
grep -q "FAILED tests/test_billing.py::test_recent_signup_has_active_trial" /tmp/before.log
grep -q "FAILED tests/test_billing.py::test_recent_signup_has_days_left" /tmp/before.log
echo "reproduced: the two recent-signup tests fail"

echo "== step 2: confirm it is a time bomb, by computation =="
python3 <<'PY'
import re
from datetime import datetime, timedelta
from pathlib import Path

src = Path("/app/tests/test_billing.py").read_text()
m = re.search(r"RECENT_SIGNUP = datetime\((\d+), (\d+), (\d+), (\d+), (\d+)\)", src)
assert m, "RECENT_SIGNUP constant not found"
signup = datetime(*map(int, m.groups()))

now = datetime.now()
window = timedelta(days=30)
print(f"signup={signup} now={now} window={window}")
assert now - signup > window, "expected the hardcoded signup to be out of window by now"
# Any 'now' within the window makes the assertions hold: pick signup + 1 day.
frozen = signup + timedelta(days=1)
assert frozen - signup < window
Path("/tmp/frozen_now.txt").write_text(frozen.strftime("%Y-%m-%d %H:%M:%S"))
print(f"bomb confirmed: suite was green while now < {signup + window}; freezing at {frozen}")
PY

echo "== step 3: freeze time in the tests (root-cause fix) =="
python3 <<'PY'
from pathlib import Path

frozen = Path("/tmp/frozen_now.txt").read_text()
path = Path("/app/tests/test_billing.py")
src = path.read_text()

assert "freeze_time" not in src
src = src.replace(
    "from datetime import datetime\n",
    "from datetime import datetime\n\n"
    "import pytest\n"
    "from freezegun import freeze_time\n",
    1,
)
fixture = (
    "\n"
    "@pytest.fixture(autouse=True)\n"
    "def _frozen_now():\n"
    "    # RECENT_SIGNUP is pinned to a fixed date; freeze 'now' inside the\n"
    "    # 30-day trial window so these tests do not depend on the wall clock.\n"
    f"    with freeze_time(\"{frozen}\"):\n"
    "        yield\n"
    "\n"
)
src = src.replace("\n\ndef test_", fixture + "\ndef test_", 1)
path.write_text(src)
print(f"froze time at {frozen} via autouse fixture in {path}")
PY

echo "== step 4: re-run to confirm =="
python -m pytest -q

cat > /app/flake_report.md <<'EOF'
# Flake report: time bomb in test_billing.py

## Symptom

`test_recent_signup_has_active_trial` and `test_recent_signup_has_days_left`
passed nightly through 2026-08-04 and then failed every night with no code
changes (see /app/ci-log.txt).

## Root cause

Time-dependent tests. `RECENT_SIGNUP` is hard-coded to 2026-07-05 09:30
while `billing.trial_active` compares against `datetime.now()` with a
30-day window. The window closed at 2026-08-04 09:30 — exactly when CI
flipped from green to red. The tests were only correct while the wall clock
stayed inside the window.

## Fix

Froze time in the tests: an autouse fixture in `tests/test_billing.py` uses
freezegun's `freeze_time` to pin "now" to 2026-07-06 09:30 (one day after
the hard-coded signup, inside the window). The tests are now independent of
the date they run on. No sleeps, no retries, and `billing.py` is unchanged.
EOF

echo "oracle done"
