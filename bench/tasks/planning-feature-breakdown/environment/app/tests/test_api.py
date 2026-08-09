import json
import tempfile
import threading
import unittest
import urllib.request
from http.server import HTTPServer

from app.api import make_handler
from app.storage import Storage


class ApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import os

        fd, db = tempfile.mkstemp(suffix=".json")
        os.close(fd)
        os.unlink(db)
        cls.server = HTTPServer(("127.0.0.1", 0), make_handler(Storage(db)))
        cls.port = cls.server.server_address[1]
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()

    def url(self, path):
        return f"http://127.0.0.1:{self.port}{path}"

    def test_health(self):
        with urllib.request.urlopen(self.url("/health")) as resp:
            self.assertEqual(resp.status, 200)

    def test_create_and_list_user(self):
        body = json.dumps({"email": "ada@example.com", "name": "Ada"}).encode()
        req = urllib.request.Request(self.url("/users"), data=body, method="POST")
        with urllib.request.urlopen(req) as resp:
            self.assertEqual(resp.status, 201)
        with urllib.request.urlopen(self.url("/users")) as resp:
            users = json.loads(resp.read())
        self.assertEqual(users[0]["email"], "ada@example.com")


if __name__ == "__main__":
    unittest.main()
