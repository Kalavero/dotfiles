import csv

from exportly.csv_export import COLUMNS, write_export


def test_write_export_matches_golden(tmp_path):
    out = tmp_path / "export.csv"
    totals = {"api_calls": 152300, "storage_gb": 420, "seats": 12}
    write_export(out, "acct-123", "2026-07", totals)

    with open(out, newline="") as fh:
        rows = list(csv.reader(fh))

    assert rows[0] == COLUMNS
    assert rows[1:] == [
        ["acct-123", "2026-07", "api_calls", "152300"],
        ["acct-123", "2026-07", "seats", "12"],
        ["acct-123", "2026-07", "storage_gb", "420"],
    ]


def test_write_export_empty_totals_writes_header_only(tmp_path):
    out = tmp_path / "export.csv"
    write_export(out, "acct-empty", "2026-07", {})
    with open(out, newline="") as fh:
        rows = list(csv.reader(fh))
    assert rows == [COLUMNS]
