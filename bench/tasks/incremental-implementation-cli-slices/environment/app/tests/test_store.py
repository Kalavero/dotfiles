import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import store


def test_load_missing_file_returns_empty_list(tmp_path):
    assert store.load_notes(str(tmp_path / "nope.json")) == []


def test_roundtrip(tmp_path):
    path = str(tmp_path / "notes.json")
    notes = [{"id": 1, "text": "hello", "tags": ["a"], "created_at": "t"}]
    store.save_notes(path, notes)
    assert store.load_notes(path) == notes
