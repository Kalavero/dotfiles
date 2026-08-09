"""Access to the usage records store.

Usage rows live in a sqlite database. Monthly aggregates are recomputed from
raw rows on every export — fine for small accounts, slow for the large ones
billing exports every month.
"""

import sqlite3
from pathlib import Path

SCHEMA = """
CREATE TABLE IF NOT EXISTS usage_events (
    account_id TEXT NOT NULL,
    event_at   TEXT NOT NULL,  -- ISO date, YYYY-MM-DD
    kind       TEXT NOT NULL,
    units      INTEGER NOT NULL
);
"""


def connect(db_path):
    """Open (creating if needed) the usage database and ensure the schema."""
    path = Path(db_path)
    conn = sqlite3.connect(path)
    conn.execute(SCHEMA)
    return conn


def monthly_rows(conn, account_id, month):
    """Return raw usage rows for an account/month, ordered by event_at.

    `month` is a YYYY-MM string matched against the event date prefix.
    """
    return list(
        conn.execute(
            "SELECT event_at, kind, units FROM usage_events "
            "WHERE account_id = ? AND substr(event_at, 1, 7) = ? "
            "ORDER BY event_at",
            (account_id, month),
        )
    )


def monthly_totals(conn, account_id, month):
    """Recompute per-kind totals by scanning every row for the month.

    This is the hot path users complain about: large accounts have hundreds
    of thousands of rows per month, and billing re-exports the same months
    repeatedly — recomputing identical totals every time.
    """
    totals = {}
    for _event_at, kind, units in monthly_rows(conn, account_id, month):
        totals[kind] = totals.get(kind, 0) + units
    return totals
