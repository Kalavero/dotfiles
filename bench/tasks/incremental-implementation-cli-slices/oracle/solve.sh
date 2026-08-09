#!/bin/bash
# Oracle: implement the notes CLI in four slices, one commit per capability,
# running the visible suite (and adding tests) between slices. Ends green.
set -euo pipefail
cd /app

# ---------------------------------------------------------------- slice 1: add
cat > notes.py <<'PY'
#!/usr/bin/env python3
"""notes - a tiny personal notes CLI storing notes in a JSON file."""
import argparse
import sys
from datetime import datetime, timezone

import store


def cmd_add(args):
    notes = store.load_notes(args.file)
    note_id = max((n["id"] for n in notes), default=0) + 1
    notes.append(
        {
            "id": note_id,
            "text": args.text,
            "tags": list(args.tag),
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
    )
    store.save_notes(args.file, notes)
    print(f"added note {note_id}")


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
PY

cat > tests/test_add.py <<'PY'
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLI = str(ROOT / "notes.py")


def run(store, *args):
    return subprocess.run(
        [sys.executable, CLI, "--file", str(store), *args],
        capture_output=True,
        text=True,
    )


def test_add_prints_id_and_persists(tmp_path):
    store = tmp_path / "notes.json"
    result = run(str(store), "add", "Buy milk", "--tag", "errands")
    assert result.returncode == 0
    assert result.stdout.strip() == "added note 1"
    notes = json.loads(store.read_text())
    assert notes[0]["text"] == "Buy milk"
    assert notes[0]["tags"] == ["errands"]


def test_add_increments_ids(tmp_path):
    store = str(tmp_path / "notes.json")
    run(store, "add", "one")
    result = run(store, "add", "two")
    assert result.stdout.strip() == "added note 2"
PY

python3 -m pytest tests/ -q
git add -A
git commit -q -m "Implement the add command"

# --------------------------------------------------------------- slice 2: list
python3 - <<'PY'
from pathlib import Path

path = Path("notes.py")
src = path.read_text()
src = src.replace(
    '''def cmd_list(args):
    raise SystemExit("list: not implemented")''',
    '''def format_note(note):
    line = f"{note['id']}: {note['text']}"
    if note.get("tags"):
        line += " [" + ",".join(note["tags"]) + "]"
    return line


def cmd_list(args):
    notes = store.load_notes(args.file)
    if args.tag is not None:
        notes = [n for n in notes if args.tag in n.get("tags", [])]
    for note in sorted(notes, key=lambda n: n["id"]):
        print(format_note(note))''',
)
path.write_text(src)
PY

cat > tests/test_list.py <<'PY'
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLI = str(ROOT / "notes.py")


def run(store, *args):
    return subprocess.run(
        [sys.executable, CLI, "--file", str(store), *args],
        capture_output=True,
        text=True,
    )


def test_list_format(tmp_path):
    store = str(tmp_path / "notes.json")
    run(store, "add", "Buy milk")
    run(store, "add", "Call the bank", "--tag", "errands", "--tag", "urgent")
    result = run(store, "list")
    assert result.stdout.splitlines() == [
        "1: Buy milk",
        "2: Call the bank [errands,urgent]",
    ]


def test_list_tag_filter(tmp_path):
    store = str(tmp_path / "notes.json")
    run(store, "add", "Buy milk", "--tag", "errands")
    run(store, "add", "Read a book")
    result = run(store, "list", "--tag", "errands")
    assert result.stdout.splitlines() == ["1: Buy milk [errands]"]
PY

python3 -m pytest tests/ -q
git add -A
git commit -q -m "Implement the list command"

# ------------------------------------------------------------- slice 3: search
python3 - <<'PY'
from pathlib import Path

path = Path("notes.py")
src = path.read_text()
src = src.replace(
    '''def cmd_search(args):
    raise SystemExit("search: not implemented")''',
    '''def cmd_search(args):
    query = args.query.lower()
    notes = store.load_notes(args.file)
    for note in sorted(notes, key=lambda n: n["id"]):
        if query in note["text"].lower():
            print(format_note(note))''',
)
path.write_text(src)
PY

cat > tests/test_search.py <<'PY'
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLI = str(ROOT / "notes.py")


def run(store, *args):
    return subprocess.run(
        [sys.executable, CLI, "--file", str(store), *args],
        capture_output=True,
        text=True,
    )


def test_search_case_insensitive(tmp_path):
    store = str(tmp_path / "notes.json")
    run(store, "add", "Buy MILK")
    run(store, "add", "Call the bank")
    run(store, "add", "milkshake recipe")
    result = run(store, "search", "milk")
    assert result.stdout.splitlines() == ["1: Buy MILK", "3: milkshake recipe"]
PY

python3 -m pytest tests/ -q
git add -A
git commit -q -m "Implement the search command"

# ------------------------------------------------------------- slice 4: export
python3 - <<'PY'
from pathlib import Path

path = Path("notes.py")
src = path.read_text()
src = src.replace(
    "import argparse\nimport sys",
    "import argparse\nimport json\nimport sys",
)
src = src.replace(
    '''def cmd_export(args):
    raise SystemExit("export: not implemented")''',
    '''def cmd_export(args):
    json.dump(store.load_notes(args.file), sys.stdout, indent=2)
    sys.stdout.write("\\n")''',
)
path.write_text(src)
PY

cat > tests/test_export.py <<'PY'
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLI = str(ROOT / "notes.py")


def run(store, *args):
    return subprocess.run(
        [sys.executable, CLI, "--file", str(store), *args],
        capture_output=True,
        text=True,
    )


def test_export_prints_json_array(tmp_path):
    store = str(tmp_path / "notes.json")
    run(store, "add", "Buy milk", "--tag", "errands")
    run(store, "add", "Call the bank")
    result = run(store, "export")
    notes = json.loads(result.stdout)
    assert [n["id"] for n in notes] == [1, 2]
    assert notes[0]["tags"] == ["errands"]
PY

python3 -m pytest tests/ -q
git add -A
git commit -q -m "Implement the export command"

python3 -m pytest tests/ -q
echo "oracle done: $(git rev-list --count HEAD) commits"
