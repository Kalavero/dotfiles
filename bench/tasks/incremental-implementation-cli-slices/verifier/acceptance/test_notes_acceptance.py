"""Hidden acceptance tests: exercise the real notes CLI end to end."""
import json
import subprocess
import sys

CLI = "/app/notes.py"


def run(store, *args):
    return subprocess.run(
        [sys.executable, CLI, "--file", str(store), *args],
        capture_output=True,
        text=True,
    )


def test_add_prints_incrementing_ids(tmp_path):
    store = str(tmp_path / "notes.json")
    r1 = run(store, "add", "Buy milk")
    assert r1.returncode == 0, r1.stderr
    assert r1.stdout.strip() == "added note 1"
    r2 = run(store, "add", "Call the bank")
    assert r2.returncode == 0, r2.stderr
    assert r2.stdout.strip() == "added note 2"


def test_add_persists_note_objects(tmp_path):
    store = tmp_path / "notes.json"
    run(str(store), "add", "Buy milk", "--tag", "errands", "--tag", "urgent")
    notes = json.loads(store.read_text())
    assert len(notes) == 1
    note = notes[0]
    assert note["id"] == 1
    assert note["text"] == "Buy milk"
    assert note["tags"] == ["errands", "urgent"]
    assert "created_at" in note


def test_list_format_with_and_without_tags(tmp_path):
    store = str(tmp_path / "notes.json")
    run(store, "add", "Buy milk")
    run(store, "add", "Call the bank", "--tag", "errands", "--tag", "urgent")
    result = run(store, "list")
    assert result.returncode == 0, result.stderr
    assert result.stdout.splitlines() == [
        "1: Buy milk",
        "2: Call the bank [errands,urgent]",
    ]


def test_list_tag_filter(tmp_path):
    store = str(tmp_path / "notes.json")
    run(store, "add", "Buy milk", "--tag", "errands")
    run(store, "add", "Read a book")
    result = run(store, "list", "--tag", "errands")
    assert result.returncode == 0, result.stderr
    assert result.stdout.splitlines() == ["1: Buy milk [errands]"]


def test_search_is_case_insensitive_substring(tmp_path):
    store = str(tmp_path / "notes.json")
    run(store, "add", "Buy MILK")
    run(store, "add", "Call the bank")
    run(store, "add", "milkshake recipe")
    result = run(store, "search", "milk")
    assert result.returncode == 0, result.stderr
    assert result.stdout.splitlines() == ["1: Buy MILK", "3: milkshake recipe"]


def test_export_prints_full_json_array(tmp_path):
    store = str(tmp_path / "notes.json")
    run(store, "add", "Buy milk", "--tag", "errands")
    run(store, "add", "Call the bank")
    result = run(store, "export")
    assert result.returncode == 0, result.stderr
    notes = json.loads(result.stdout)
    assert [n["id"] for n in notes] == [1, 2]
    assert notes[0]["text"] == "Buy milk"
    assert notes[0]["tags"] == ["errands"]
    assert notes[1]["text"] == "Call the bank"
