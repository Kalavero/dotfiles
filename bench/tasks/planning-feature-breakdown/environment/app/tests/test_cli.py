import contextlib
import io
import json
import os
import tempfile
import unittest

from app.cli import main


class CliTests(unittest.TestCase):
    def setUp(self):
        fd, self.db = tempfile.mkstemp(suffix=".json")
        os.close(fd)
        os.unlink(self.db)

    def run_cli(self, *argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            main(["--db", self.db, *argv])
        return out.getvalue().strip()

    def test_user_create_then_list(self):
        created = json.loads(self.run_cli("user", "create", "ada@example.com", "Ada"))
        self.assertEqual(created["id"], 1)
        listed = json.loads(self.run_cli("user", "list"))
        self.assertEqual(listed[0]["name"], "Ada")

    def test_project_create(self):
        created = json.loads(self.run_cli("project", "create", "Apollo", "1"))
        self.assertEqual(created["owner_id"], 1)


if __name__ == "__main__":
    unittest.main()
