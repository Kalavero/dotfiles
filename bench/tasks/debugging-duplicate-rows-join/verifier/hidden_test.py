"""Hidden behavior test, mounted only at verify time.

Asserts the fixed query layer returns each seeded user exactly once AND
preserves every role that user holds. Expectations are hardcoded here (not
derived from /app/seed.py) so tampering with the seed data is caught too.
"""

import os
import sys
import tempfile

sys.path.insert(0, "/app")

import seed  # noqa: E402
from queries import list_users_with_roles  # noqa: E402

EXPECTED_ROLES = {
    1: {"admin", "editor", "viewer"},   # Ada Lovelace
    2: {"editor"},                      # Grace Hopper
    3: {"viewer"},                      # Edsger Dijkstra
    4: {"admin", "viewer"},             # Barbara Liskov
}


def _roles_of(user):
    roles = user.get("roles")
    if isinstance(roles, (list, tuple, set)):
        return {str(r).strip() for r in roles}
    return {r.strip() for r in str(user.get("role", "")).split(",") if r.strip()}


def test_users_returned_once_with_all_roles():
    with tempfile.TemporaryDirectory() as d:
        db = seed.build_db(os.path.join(d, "hidden.db"))
        users = list_users_with_roles(db)
    ids = [u["id"] for u in users]
    assert len(ids) == len(set(ids)), f"duplicate users returned: {sorted(ids)}"
    assert set(ids) == set(EXPECTED_ROLES), (
        f"missing or extra users: {sorted(set(ids))}"
    )
    for u in users:
        assert _roles_of(u) == EXPECTED_ROLES[u["id"]], (
            f"user {u['id']} lost roles: {_roles_of(u)} != "
            f"{EXPECTED_ROLES[u['id']]}"
        )
