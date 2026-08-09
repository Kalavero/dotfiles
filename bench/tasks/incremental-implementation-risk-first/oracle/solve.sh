#!/bin/bash
# Oracle: implement csvstat in four slices, one commit per command, running
# the visible suite (and adding tests) between slices. Slice 1 takes the
# risky piece first: encoding + delimiter detection behind `inspect`.
set -euo pipefail
cd /app

# ------------------------------------------- slice 1: loader + inspect (risky)
cat > csvstat.py <<'PY'
#!/usr/bin/env python3
"""csvstat - inspect and query CSV files with automatic dialect detection."""
import argparse
import csv
import io
import sys

CANDIDATE_DELIMITERS = [",", ";", "\t", "|"]


def detect_encoding(raw):
    try:
        raw.decode("utf-8")
        return "utf-8"
    except UnicodeDecodeError:
        return "latin-1"


def detect_delimiter(text):
    lines = [line for line in text.splitlines() if line.strip()][:20]
    best, best_score = ",", -1.0
    for candidate in CANDIDATE_DELIMITERS:
        counts = [len(next(csv.reader([line], delimiter=candidate))) for line in lines]
        if max(counts) <= 1:
            continue
        score = max(counts) - counts.count(max(counts)) * 0.5
        if score > best_score:
            best, best_score = candidate, score
    return best


def load(path):
    with open(path, "rb") as fh:
        raw = fh.read()
    encoding = detect_encoding(raw)
    text = raw.decode(encoding)
    delimiter = detect_delimiter(text)
    rows = list(csv.reader(io.StringIO(text), delimiter=delimiter))
    return encoding, delimiter, rows


def cmd_inspect(args):
    encoding, delimiter, rows = load(args.file)
    print(f"encoding: {encoding}")
    print(f'delimiter: "{delimiter}"')
    print("columns: " + ",".join(rows[0]))


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
PY

cat > tests/test_inspect.py <<'PY'
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLI = str(ROOT / "csvstat.py")


def run_cli(*args):
    return subprocess.run(
        [sys.executable, CLI, *args],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
    )


def test_inspect_tricky_fixture():
    result = run_cli("inspect", "fixtures/tricky.csv")
    assert result.returncode == 0
    assert result.stdout.splitlines() == [
        "encoding: latin-1",
        'delimiter: ";"',
        "columns: name,city,score",
    ]


def test_inspect_people_fixture():
    result = run_cli("inspect", "fixtures/people.csv")
    assert result.stdout.splitlines() == [
        "encoding: utf-8",
        'delimiter: ","',
        "columns: name,department,salary",
    ]
PY

python3 -m pytest tests/ -q
git add -A
git commit -q -m "Implement inspect with encoding and delimiter detection"

# -------------------------------------------------------------- slice 2: count
python3 - <<'PY'
from pathlib import Path

path = Path("csvstat.py")
src = path.read_text()
src = src.replace(
    '''def cmd_count(args):
    raise SystemExit("count: not implemented")''',
    '''def cmd_count(args):
    _, _, rows = load(args.file)
    print(f"rows: {len(rows) - 1}")''',
)
path.write_text(src)
PY

cat > tests/test_count.py <<'PY'
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLI = str(ROOT / "csvstat.py")


def run_cli(*args):
    return subprocess.run(
        [sys.executable, CLI, *args],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
    )


def test_count_excludes_header():
    assert run_cli("count", "fixtures/tricky.csv").stdout.strip() == "rows: 3"
    assert run_cli("count", "fixtures/people.csv").stdout.strip() == "rows: 3"
PY

python3 -m pytest tests/ -q
git add -A
git commit -q -m "Implement the count command"

# -------------------------------------------------------------- slice 3: stats
python3 - <<'PY'
from pathlib import Path

path = Path("csvstat.py")
src = path.read_text()
src = src.replace(
    '''def cmd_stats(args):
    raise SystemExit("stats: not implemented")''',
    '''def cmd_stats(args):
    _, _, rows = load(args.file)
    index = rows[0].index(args.column)
    values = [float(row[index]) for row in rows[1:] if row[index].strip()]
    print(f"count: {len(values)}")
    print(f"min: {min(values):.2f}")
    print(f"max: {max(values):.2f}")
    print(f"mean: {sum(values) / len(values):.2f}")''',
)
path.write_text(src)
PY

cat > tests/test_stats.py <<'PY'
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLI = str(ROOT / "csvstat.py")


def run_cli(*args):
    return subprocess.run(
        [sys.executable, CLI, *args],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
    )


def test_stats_score_column():
    result = run_cli("stats", "fixtures/tricky.csv", "score")
    assert result.stdout.splitlines() == [
        "count: 3",
        "min: 7.25",
        "max: 9.50",
        "mean: 8.25",
    ]


def test_stats_salary_column():
    result = run_cli("stats", "fixtures/people.csv", "salary")
    assert result.stdout.splitlines()[-1] == "mean: 85000.00"
PY

python3 -m pytest tests/ -q
git add -A
git commit -q -m "Implement the stats command"

# ------------------------------------------------------------- slice 4: filter
python3 - <<'PY'
from pathlib import Path

path = Path("csvstat.py")
src = path.read_text()
src = src.replace(
    '''def cmd_filter(args):
    raise SystemExit("filter: not implemented")''',
    '''def cmd_filter(args):
    _, _, rows = load(args.file)
    index = rows[0].index(args.column)
    writer = csv.writer(sys.stdout, lineterminator="\\n")
    writer.writerow(rows[0])
    for row in rows[1:]:
        if row[index] == args.value:
            writer.writerow(row)''',
)
path.write_text(src)
PY

cat > tests/test_filter.py <<'PY'
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLI = str(ROOT / "csvstat.py")


def run_cli(*args):
    return subprocess.run(
        [sys.executable, CLI, *args],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
    )


def test_filter_exact_match():
    result = run_cli("filter", "fixtures/people.csv", "department", "Engineering")
    assert result.stdout.splitlines() == [
        "name,department,salary",
        "Alice,Engineering,95000",
        "Carol,Engineering,88000",
    ]


def test_filter_decodes_latin1_fixture():
    result = run_cli("filter", "fixtures/tricky.csv", "city", "São Paulo")
    assert result.stdout.splitlines() == [
        "name,city,score",
        "Ana; Maria,São Paulo,9.5",
    ]
PY

python3 -m pytest tests/ -q
git add -A
git commit -q -m "Implement the filter command"

python3 -m pytest tests/ -q
echo "oracle done: $(git rev-list --count HEAD) commits"
