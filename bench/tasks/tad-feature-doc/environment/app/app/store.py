"""JSON-file-backed storage for widgets and API keys.

Everything goes through the same load/save pattern: one JSON document per
collection, written wholesale under a lock. Good enough for a single-process
deployment.
"""

import json
import os
import threading


class Store:
    def __init__(self, data_dir):
        self.data_dir = data_dir
        self._lock = threading.Lock()
        os.makedirs(data_dir, exist_ok=True)

    def _path(self, name):
        return os.path.join(self.data_dir, f"{name}.json")

    def _load(self, name):
        path = self._path(name)
        if not os.path.exists(path):
            return {}
        with open(path) as fh:
            return json.load(fh)

    def _save(self, name, data):
        with self._lock:
            with open(self._path(name), "w") as fh:
                json.dump(data, fh, indent=2)

    # API keys: {key: {"tier": "free"|"pro"|"enterprise", "owner": str}}

    def get_api_key(self, key):
        return self._load("api_keys").get(key)

    # Widgets: {id: {"id": str, "name": str, ...}}

    def list_widgets(self):
        return list(self._load("widgets").values())

    def get_widget(self, widget_id):
        return self._load("widgets").get(widget_id)

    def create_widget(self, widget):
        widgets = self._load("widgets")
        widgets[widget["id"]] = widget
        self._save("widgets", widgets)
        return widget
