"""Command-line interface for the projects app."""

from __future__ import annotations

import argparse
import json

from .storage import Storage

DEFAULT_DB = "data.json"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="projects")
    parser.add_argument("--db", default=DEFAULT_DB, help="path to the JSON data file")
    resources = parser.add_subparsers(dest="resource", required=True)

    for resource in ("user", "project"):
        res = resources.add_parser(resource)
        actions = res.add_subparsers(dest="action", required=True)
        create = actions.add_parser("create")
        if resource == "user":
            create.add_argument("email")
            create.add_argument("name")
        else:
            create.add_argument("name")
            create.add_argument("owner_id", type=int)
        actions.add_parser("list")
    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    storage = Storage(args.db)
    collection = args.resource + "s"
    if args.action == "create":
        record = {
            key: value
            for key, value in vars(args).items()
            if key not in ("db", "resource", "action")
        }
        print(json.dumps(storage.insert(collection, record)))
    else:
        print(json.dumps(storage.all(collection)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
