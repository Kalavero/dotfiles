#!/usr/bin/env python3
"""csvstat - inspect and query CSV files with automatic dialect detection."""
import argparse
import sys


def cmd_inspect(args):
    raise SystemExit("inspect: not implemented")


def cmd_count(args):
    raise SystemExit("count: not implemented")


def cmd_stats(args):
    raise SystemExit("stats: not implemented")


def cmd_filter(args):
    raise SystemExit("filter: not implemented")


def build_parser():
    parser = argparse.ArgumentParser(prog="csvstat", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    p_inspect = sub.add_parser(
        "inspect", help="print detected encoding, delimiter, and columns"
    )
    p_inspect.add_argument("file")
    p_inspect.set_defaults(func=cmd_inspect)

    p_count = sub.add_parser("count", help="print the number of data rows")
    p_count.add_argument("file")
    p_count.set_defaults(func=cmd_count)

    p_stats = sub.add_parser("stats", help="print stats for a numeric column")
    p_stats.add_argument("file")
    p_stats.add_argument("column")
    p_stats.set_defaults(func=cmd_stats)

    p_filter = sub.add_parser(
        "filter", help="print rows where a column equals a value, as CSV"
    )
    p_filter.add_argument("file")
    p_filter.add_argument("column")
    p_filter.add_argument("value")
    p_filter.set_defaults(func=cmd_filter)

    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    args.func(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
