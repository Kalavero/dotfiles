"""Command-line interface for the projects app."""

from __future__ import annotations

import argparse
import json

from .reports import usage_summary
from .storage import Storage

DEFAULT_DB = "data.sqlite3"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="projects")
    parser.add_argument("--db", default=DEFAULT_DB, help="path to the SQLite database")
    commands = parser.add_subparsers(dest="command", required=True)

    for resource in ("user", "project"):
        res = commands.add_parser(resource)
        actions = res.add_subparsers(dest="action", required=True)
        create = actions.add_parser("create")
        if resource == "user":
            create.add_argument("email")
            create.add_argument("name")
        else:
            create.add_argument("name")
            create.add_argument("owner_id", type=int)
        actions.add_parser("list")

    commands.add_parser("summary", help="print a usage summary")
    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    storage = Storage(args.db)
    if args.command == "summary":
        print(json.dumps(usage_summary(storage)))
        return 0
    collection = args.command + "s"
    if args.action == "create":
        record = {
            key: value
            for key, value in vars(args).items()
            if key not in ("db", "command", "action")
        }
        print(json.dumps(storage.insert(collection, record)))
    else:
        print(json.dumps(storage.all(collection)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
