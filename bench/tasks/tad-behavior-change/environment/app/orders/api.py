"""Minimal stdlib WSGI API for orders."""

import json
import os
import re
from wsgiref.simple_server import make_server

from orders.refunds import RefundClient
from orders.service import CancellationError, cancel_order
from orders.store import Store

DATA_DIR = os.environ.get("ORDERS_DATA_DIR", "./data")
HOST = os.environ.get("ORDERS_HOST", "0.0.0.0")
PORT = int(os.environ.get("ORDERS_PORT", "8080"))

store = Store(DATA_DIR)
refunds = RefundClient()

REASONS = {200: "OK", 400: "Bad Request", 404: "Not Found", 409: "Conflict"}

ORDER_RE = re.compile(r"^/orders/([\w-]+)$")
CANCEL_RE = re.compile(r"^/orders/([\w-]+)/cancel$")


def _json(start_response, status, payload):
    body = json.dumps(payload).encode()
    start_response(
        f"{status} {REASONS[status]}",
        [("Content-Type", "application/json"), ("Content-Length", str(len(body)))],
    )
    return [body]


def application(environ, start_response):
    method = environ["REQUEST_METHOD"]
    path = environ["PATH_INFO"]

    order_match = ORDER_RE.match(path)
    if method == "GET" and order_match:
        order = store.get_order(order_match.group(1))
        if order is None:
            return _json(start_response, 404, {"error": "order not found"})
        return _json(start_response, 200, {"order": order.__dict__})

    cancel_match = CANCEL_RE.match(path)
    if method == "POST" and cancel_match:
        try:
            order = cancel_order(store, refunds, cancel_match.group(1))
        except CancellationError as exc:
            return _json(start_response, 409, {"error": str(exc)})
        return _json(start_response, 200, {"order": order.__dict__})

    return _json(start_response, 404, {"error": "not found"})


def main():
    make_server(HOST, PORT, application).serve_forever()


if __name__ == "__main__":
    main()
