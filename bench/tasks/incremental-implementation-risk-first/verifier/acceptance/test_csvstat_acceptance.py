"""Hidden acceptance tests: exercise the real csvstat CLI end to end."""
import subprocess
import sys

CLI = "/app/csvstat.py"
PEOPLE = "/app/fixtures/people.csv"
TRICKY = "/app/fixtures/tricky.csv"


def run(*args):
    return subprocess.run(
        [sys.executable, CLI, *args],
        capture_output=True,
        text=True,
        cwd="/app",
    )


def test_inspect_tricky_detects_latin1_semicolon():
    result = run("inspect", TRICKY)
    assert result.returncode == 0, result.stderr
    assert result.stdout.splitlines() == [
        "encoding: latin-1",
        'delimiter: ";"',
        "columns: name,city,score",
    ]


def test_inspect_people_detects_utf8_comma():
    result = run("inspect", PEOPLE)
    assert result.returncode == 0, result.stderr
    assert result.stdout.splitlines() == [
        "encoding: utf-8",
        'delimiter: ","',
        "columns: name,department,salary",
    ]


def test_count_data_rows():
    assert run("count", TRICKY).stdout.strip() == "rows: 3"
    assert run("count", PEOPLE).stdout.strip() == "rows: 3"


def test_stats_numeric_column_tricky():
    result = run("stats", TRICKY, "score")
    assert result.returncode == 0, result.stderr
    assert result.stdout.splitlines() == [
        "count: 3",
        "min: 7.25",
        "max: 9.50",
        "mean: 8.25",
    ]


def test_stats_numeric_column_people():
    result = run("stats", PEOPLE, "salary")
    assert result.returncode == 0, result.stderr
    assert result.stdout.splitlines() == [
        "count: 3",
        "min: 72000.00",
        "max: 95000.00",
        "mean: 85000.00",
    ]


def test_filter_exact_match_outputs_csv():
    result = run("filter", PEOPLE, "department", "Engineering")
    assert result.returncode == 0, result.stderr
    assert result.stdout.splitlines() == [
        "name,department,salary",
        "Alice,Engineering,95000",
        "Carol,Engineering,88000",
    ]


def test_filter_on_tricky_fixture_decodes_latin1():
    result = run("filter", TRICKY, "city", "São Paulo")
    assert result.returncode == 0, result.stderr
    assert result.stdout.splitlines() == [
        "name,city,score",
        "Ana; Maria,São Paulo,9.5",
    ]
