"""Query layer for the user directory app."""

import sqlite3

DEFAULT_DB = "app.db"


def list_users_with_roles(db_path=DEFAULT_DB):
    """Return every user together with their roles.

    Each entry is a dict: {"id", "name", "email", "role"}.
    """
    conn = sqlite3.connect(db_path)
    try:
        rows = conn.execute(
            """
            SELECT u.id, u.name, u.email, r.name AS role
            FROM users u
            JOIN user_roles ur ON ur.user_id = u.id
            JOIN roles r ON r.id = ur.role_id
            ORDER BY u.id, r.name
            """
        ).fetchall()
    finally:
        conn.close()
    return [
        {"id": user_id, "name": name, "email": email, "role": role}
        for user_id, name, email, role in rows
    ]
