"""Seed data for the user directory app.

Builds a small SQLite database with users, roles, and a many-to-many
user_roles mapping. Run directly (`python3 seed.py`) to create ./app.db
for manual exploration.
"""

import sqlite3

DB_PATH = "app.db"

USERS = [
    (1, "Ada Lovelace", "ada@example.com"),
    (2, "Grace Hopper", "grace@example.com"),
    (3, "Edsger Dijkstra", "edsger@example.com"),
    (4, "Barbara Liskov", "barbara@example.com"),
]

ROLES = [
    (1, "admin"),
    (2, "editor"),
    (3, "viewer"),
]

USER_ROLES = [
    (1, 1),  # Ada: admin
    (1, 2),  # Ada: editor
    (1, 3),  # Ada: viewer
    (2, 2),  # Grace: editor
    (3, 3),  # Edsger: viewer
    (4, 1),  # Barbara: admin
    (4, 3),  # Barbara: viewer
]

SCHEMA = """
CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL
);
CREATE TABLE roles (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);
CREATE TABLE user_roles (
    user_id INTEGER NOT NULL REFERENCES users(id),
    role_id INTEGER NOT NULL REFERENCES roles(id),
    PRIMARY KEY (user_id, role_id)
);
"""


def expected_roles():
    """{user_id: {role_name, ...}} derived from the seed data."""
    role_names = dict(ROLES)
    result = {}
    for user_id, role_id in USER_ROLES:
        result.setdefault(user_id, set()).add(role_names[role_id])
    return result


def build_db(db_path=DB_PATH):
    """Create a fresh database at db_path populated with the seed data."""
    conn = sqlite3.connect(db_path)
    try:
        conn.executescript(SCHEMA)
        conn.executemany("INSERT INTO users VALUES (?, ?, ?)", USERS)
        conn.executemany("INSERT INTO roles VALUES (?, ?)", ROLES)
        conn.executemany("INSERT INTO user_roles VALUES (?, ?)", USER_ROLES)
        conn.commit()
    finally:
        conn.close()
    return db_path


if __name__ == "__main__":
    build_db()
    print(f"seeded {DB_PATH}")
