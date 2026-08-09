"""Command-line interface for exportly."""

import argparse

from .csv_export import write_export
from .db import connect, monthly_totals


def build_parser():
    parser = argparse.ArgumentParser(
        prog="exportly", description="Export usage records to CSV."
    )
    sub = parser.add_subparsers(dest="command", required=True)
    export = sub.add_parser("export", help="Export one account/month to CSV.")
    export.add_argument("--account", required=True, help="Account ID, e.g. acct-123")
    export.add_argument("--month", required=True, help="Month as YYYY-MM")
    export.add_argument("--db", default="usage.db", help="Path to the usage database")
    export.add_argument("--out", required=True, help="Output CSV path")
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    if args.command == "export":
        conn = connect(args.db)
        totals = monthly_totals(conn, args.account, args.month)
        write_export(args.out, args.account, args.month, totals)
        rows = sum(1 for _ in totals)
        print(f"wrote {rows} kind rows for {args.account} {args.month} -> {args.out}")
