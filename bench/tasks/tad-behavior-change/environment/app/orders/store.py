"""JSON-file-backed order persistence, one document per collection."""

import json
import os
import threading

from orders.models import Order


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

    def get_order(self, order_id):
        raw = self._load("orders").get(order_id)
        return Order(**raw) if raw else None

    def save_order(self, order):
        orders = self._load("orders")
        orders[order.id] = {
            "id": order.id,
            "account_id": order.account_id,
            "total_cents": order.total_cents,
            "status": order.status,
            "refunded_cents": order.refunded_cents,
        }
        self._save("orders", orders)
        return order
