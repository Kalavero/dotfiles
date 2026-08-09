import io
import json
import os
import tempfile
import unittest

from app import server
from app.store import Store


def call(app, method, path, key=None, payload=None):
    body = json.dumps(payload).encode() if payload is not None else b""
    environ = {
        "REQUEST_METHOD": method,
        "PATH_INFO": path,
        "CONTENT_LENGTH": str(len(body)),
        "wsgi.input": io.BytesIO(body),
    }
    if key:
        environ["HTTP_X_API_KEY"] = key
    captured = {}

    def start_response(status, headers):
        captured["status"] = status
        captured["headers"] = dict(headers)

    response_body = b"".join(app(environ, start_response))
    return captured["status"], json.loads(response_body)


class ServerTest(unittest.TestCase):
    def setUp(self):
        self.data_dir = tempfile.mkdtemp()
        server.store = Store(self.data_dir)
        with open(os.path.join(self.data_dir, "api_keys.json"), "w") as fh:
            json.dump({"k1": {"tier": "free", "owner": "ada"}}, fh)

    def test_health_needs_no_key(self):
        status, body = call(server.application, "GET", "/health")
        self.assertTrue(status.startswith("200"))
        self.assertEqual(body["status"], "ok")

    def test_widgets_requires_auth(self):
        status, _ = call(server.application, "GET", "/widgets")
        self.assertTrue(status.startswith("401"))

    def test_create_then_get_widget(self):
        call(server.application, "POST", "/widgets", key="k1",
             payload={"id": "w1", "name": "sprocket"})
        status, body = call(server.application, "GET", "/widgets/w1", key="k1")
        self.assertTrue(status.startswith("200"))
        self.assertEqual(body["name"], "sprocket")


if __name__ == "__main__":
    unittest.main()
