import csv

from exportly.cli import main
from exportly.db import connect


def seed(db_path):
    conn = connect(db_path)
    conn.executemany(
        "INSERT INTO usage_events (account_id, event_at, kind, units) "
        "VALUES (?, ?, ?, ?)",
        [
            ("acct-1", "2026-07-01", "api_calls", 100),
            ("acct-1", "2026-07-15", "api_calls", 250),
            ("acct-1", "2026-07-15", "seats", 3),
            ("acct-1", "2026-08-01", "api_calls", 999),  # other month
            ("acct-2", "2026-07-03", "api_calls", 777),  # other account
        ],
    )
    conn.commit()
    conn.close()


def test_export_cli_end_to_end(tmp_path):
    db = tmp_path / "usage.db"
    out = tmp_path / "export.csv"
    seed(db)

    main(
        [
            "export",
            "--account", "acct-1",
            "--month", "2026-07",
            "--db", str(db),
            "--out", str(out),
        ]
    )

    with open(out, newline="") as fh:
        rows = list(csv.reader(fh))
    assert rows[1:] == [
        ["acct-1", "2026-07", "api_calls", "350"],
        ["acct-1", "2026-07", "seats", "3"],
    ]
