#!/bin/bash
# Oracle for debugging-duplicate-rows-join: reproduce the failure, localize
# it to the query layer, fix the JOIN fan-out there, add a regression test,
# and verify the whole suite.
set -euo pipefail
cd /app

echo "== step 1: reproduce the failure =="
if python3 -m pytest tests -q 2>&1 | tee /tmp/repro.txt; then
  echo "ERROR: suite unexpectedly green; nothing to fix" >&2
  exit 1
fi
grep -q "test_render_lists_each_user_exactly_once" /tmp/repro.txt

echo "== step 2: localize — count rows per user coming out of the query layer =="
python3 - <<'PY'
from collections import Counter

import queries
import seed

db = seed.build_db("/tmp/diagnose.db")
rows = queries.list_users_with_roles(db)
per_user = Counter(r["id"] for r in rows)
dupes = {uid: n for uid, n in per_user.items() if n > 1}
print(f"{len(rows)} rows returned for {len(per_user)} users; rows per user: {dict(per_user)}")
assert dupes, "expected duplicate users from the query layer"
print("root cause is in queries.py (one row per joined role), not render.py")
PY

echo "== step 3: fix the root cause in the query layer =="
cat > queries.py <<'EOF'
"""Query layer for the user directory app."""

import sqlite3

DEFAULT_DB = "app.db"


def list_users_with_roles(db_path=DEFAULT_DB):
    """Return every user together with their roles.

    Each entry is a dict: {"id", "name", "email", "role"} where "role"
    holds all of the user's roles joined with ", ". One entry per user.
    """
    conn = sqlite3.connect(db_path)
    try:
        rows = conn.execute(
            """
            SELECT u.id, u.name, u.email, GROUP_CONCAT(r.name, ', ') AS role
            FROM users u
            JOIN user_roles ur ON ur.user_id = u.id
            JOIN roles r ON r.id = ur.role_id
            GROUP BY u.id, u.name, u.email
            ORDER BY u.id
            """
        ).fetchall()
    finally:
        conn.close()
    return [
        {"id": user_id, "name": name, "email": email, "role": role}
        for user_id, name, email, role in rows
    ]
EOF

echo "== step 4: add a regression test =="
cat > tests/test_duplicate_users_regression.py <<'EOF'
"""Regression test: the user list showed each user once per role they held,
because the query layer returned one row per (user, role) join row."""

import seed
from queries import list_users_with_roles
from render import render_user_list


def _roles(user):
    return {r.strip() for r in user["role"].split(",") if r.strip()}


def test_each_user_returned_once_with_all_roles(db_path):
    users = list_users_with_roles(db_path)
    ids = [u["id"] for u in users]
    assert len(ids) == len(set(ids)), "query layer returned duplicate users"
    expected = seed.expected_roles()
    assert set(ids) == set(expected)
    for u in users:
        assert _roles(u) == expected[u["id"]], (
            f"roles lost for {u['name']}: {_roles(u)} != {expected[u['id']]}"
        )


def test_rendered_list_has_no_duplicate_users(db_path):
    output = render_user_list(db_path)
    for _, name, _ in seed.USERS:
        assert output.count(name) == 1
EOF

echo "== step 5: write the cause summary =="
cat > CAUSE.md <<'EOF'
# Root cause: JOIN fan-out in list_users_with_roles

`queries.py` joined users -> user_roles -> roles and returned one dict per
joined row, so a user with N roles appeared N times. `render.py` only
displayed what the query returned, which is why the duplicates showed up in
the output even though the presentation layer was fine.

Fix: aggregate in the query — GROUP BY the user and GROUP_CONCAT the role
names — so each user is returned exactly once with all of their roles.
Deduplicating in render.py would only have hidden the symptom while still
returning wrong data (one row per role) to every other caller.
EOF

echo "== step 6: verify end-to-end =="
python3 -m pytest tests -q
