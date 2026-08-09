"""JSON file storage helpers for the notes CLI."""
import json
import os


def load_notes(path):
    """Return the list of notes stored at *path*, or [] if it does not exist."""
    if not os.path.exists(path):
        return []
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def save_notes(path, notes):
    """Write *notes* (a list of dicts) to *path* as pretty-printed JSON."""
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(notes, fh, indent=2)
        fh.write("\n")
