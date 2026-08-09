#!/usr/bin/env python3
"""notes - a tiny personal notes CLI storing notes in a JSON file."""
import argparse
import sys

import store


def cmd_add(args):
    raise SystemExit("add: not implemented")


def cmd_list(args):
    raise SystemExit("list: not implemented")


def cmd_search(args):
    raise SystemExit("search: not implemented")


def cmd_export(args):
    raise SystemExit("export: not implemented")


def build_parser():
    parser = argparse.ArgumentParser(prog="notes", description=__doc__)
    parser.add_argument(
        "--file",
        default="notes.json",
        help="path to the JSON store (default: ./notes.json)",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_add = sub.add_parser("add", help="add a note")
    p_add.add_argument("text")
    p_add.add_argument("--tag", action="append", default=[])
    p_add.set_defaults(func=cmd_add)

    p_list = sub.add_parser("list", help="list notes")
    p_list.add_argument("--tag", default=None)
    p_list.set_defaults(func=cmd_list)

    p_search = sub.add_parser("search", help="search notes by substring")
    p_search.add_argument("query")
    p_search.set_defaults(func=cmd_search)

    p_export = sub.add_parser("export", help="export notes as JSON to stdout")
    p_export.set_defaults(func=cmd_export)

    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    args.func(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
