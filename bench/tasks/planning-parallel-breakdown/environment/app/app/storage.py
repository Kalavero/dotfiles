"""SQLite persistence with file-based migrations.

Migration files live in ../migrations as NNNN_name.sql and are applied in
sorted order; applied names are recorded in the schema_migrations table.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

MIGRATIONS_DIR = Path(__file__).resolve().parent.parent / "migrations"


class Storage:
    def __init__(self, path: str):
        self.path = path
        self._migrate()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.path)
        conn.row_factory = sqlite3.Row
        return conn

    def _migrate(self) -> None:
        with self._connect() as conn:
            conn.execute(
                "CREATE TABLE IF NOT EXISTS schema_migrations (name TEXT PRIMARY KEY)"
            )
            applied = {
                row["name"] for row in conn.execute("SELECT name FROM schema_migrations")
            }
            for sql_file in sorted(MIGRATIONS_DIR.glob("*.sql")):
                if sql_file.name in applied:
                    continue
                conn.executescript(sql_file.read_text())
                conn.execute(
                    "INSERT INTO schema_migrations (name) VALUES (?)", (sql_file.name,)
                )

    def insert(self, table: str, record: dict) -> dict:
        cols = ", ".join(record)
        placeholders = ", ".join("?" for _ in record)
        with self._connect() as conn:
            cur = conn.execute(
                f"INSERT INTO {table} ({cols}) VALUES ({placeholders})",
                tuple(record.values()),
            )
            record_id = cur.lastrowid
        return self.get(table, record_id)

    def all(self, table: str) -> list:
        with self._connect() as conn:
            return [dict(row) for row in conn.execute(f"SELECT * FROM {table} ORDER BY id")]

    def get(self, table: str, record_id: int):
        with self._connect() as conn:
            row = conn.execute(
                f"SELECT * FROM {table} WHERE id = ?", (record_id,)
            ).fetchone()
            return dict(row) if row else None
