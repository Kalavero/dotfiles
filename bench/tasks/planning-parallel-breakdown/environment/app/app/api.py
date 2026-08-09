"""Minimal JSON HTTP API built on the standard library."""

from __future__ import annotations

import json
from http.server import BaseHTTPRequestHandler, HTTPServer

from .storage import Storage

RESOURCES = ("users", "projects")


def make_handler(storage: Storage):
    class Handler(BaseHTTPRequestHandler):
        def _send(self, code: int, payload) -> None:
            body = json.dumps(payload).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def _body(self) -> dict:
            length = int(self.headers.get("Content-Length") or 0)
            raw = self.rfile.read(length) if length else b"{}"
            return json.loads(raw)

        def do_GET(self) -> None:
            if self.path == "/health":
                self._send(200, {"status": "ok"})
            elif self.path.strip("/") in RESOURCES:
                self._send(200, storage.all(self.path.strip("/")))
            else:
                self._send(404, {"error": "not found"})

        def do_POST(self) -> None:
            resource = self.path.strip("/")
            if resource not in RESOURCES:
                self._send(404, {"error": "not found"})
                return
            payload = self._body()
            if resource == "users" and not payload.get("email"):
                self._send(400, {"error": "email is required"})
                return
            if resource == "projects" and not payload.get("name"):
                self._send(400, {"error": "name is required"})
                return
            self._send(201, storage.insert(resource, payload))

        def log_message(self, *args) -> None:  # keep test output quiet
            pass

    return Handler


def serve(storage: Storage, host: str = "127.0.0.1", port: int = 8080) -> None:
    HTTPServer((host, port), make_handler(storage)).serve_forever()
