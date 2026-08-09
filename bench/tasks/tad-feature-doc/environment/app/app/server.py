"""Minimal stdlib WSGI server exposing the widget inventory API."""

import json
import re
from wsgiref.simple_server import make_server

from app import config
from app.auth import AuthError, authenticate
from app.store import Store

store = Store(config.DATA_DIR)

REASONS = {
    200: "OK",
    201: "Created",
    400: "Bad Request",
    401: "Unauthorized",
    404: "Not Found",
}

WIDGET_RE = re.compile(r"^/widgets/([\w-]+)$")


def _json(start_response, status, payload, extra_headers=None):
    body = json.dumps(payload).encode()
    headers = [
        ("Content-Type", "application/json"),
        ("Content-Length", str(len(body))),
    ]
    headers.extend(extra_headers or [])
    start_response(f"{status} {REASONS[status]}", headers)
    return [body]


def application(environ, start_response):
    method = environ["REQUEST_METHOD"]
    path = environ["PATH_INFO"]

    if method == "GET" and path == "/health":
        return _json(start_response, 200, {"status": "ok"})

    try:
        caller = authenticate(environ, store)
    except AuthError as exc:
        return _json(start_response, 401, {"error": str(exc)})

    if method == "GET" and path == "/widgets":
        return _json(
            start_response, 200,
            {"widgets": store.list_widgets(), "tier": caller["tier"]},
        )

    widget_match = WIDGET_RE.match(path)
    if method == "GET" and widget_match:
        widget = store.get_widget(widget_match.group(1))
        if widget is None:
            return _json(start_response, 404, {"error": "widget not found"})
        return _json(start_response, 200, widget)

    if method == "POST" and path == "/widgets":
        length = int(environ.get("CONTENT_LENGTH") or 0)
        payload = json.loads(environ["wsgi.input"].read(length) or b"{}")
        if "id" not in payload or "name" not in payload:
            return _json(start_response, 400, {"error": "id and name are required"})
        return _json(start_response, 201, store.create_widget(payload))

    return _json(start_response, 404, {"error": "not found"})


def main():
    make_server(config.HOST, config.PORT, application).serve_forever()


if __name__ == "__main__":
    main()
