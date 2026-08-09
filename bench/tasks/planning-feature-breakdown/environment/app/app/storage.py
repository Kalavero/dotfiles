"""JSON-file persistence for the projects app.

All data lives in a single JSON document with one list per collection and an
integer counter per collection for id allocation.
"""

from __future__ import annotations

import json
import os
import threading


class Storage:
    def __init__(self, path: str):
        self.path = path
        self._lock = threading.Lock()
        if not os.path.exists(path):
            self._write({"counters": {}, "users": [], "projects": []})

    def _read(self) -> dict:
        with open(self.path) as fh:
            return json.load(fh)

    def _write(self, data: dict) -> None:
        tmp = self.path + ".tmp"
        with open(tmp, "w") as fh:
            json.dump(data, fh, indent=2)
        os.replace(tmp, self.path)

    def insert(self, collection: str, record: dict) -> dict:
        with self._lock:
            data = self._read()
            data.setdefault(collection, [])
            next_id = data["counters"].get(collection, 0) + 1
            data["counters"][collection] = next_id
            record = {"id": next_id, **record}
            data[collection].append(record)
            self._write(data)
            return record

    def all(self, collection: str) -> list:
        return list(self._read().get(collection, []))

    def get(self, collection: str, record_id: int):
        for record in self._read().get(collection, []):
            if record["id"] == record_id:
                return record
        return None
