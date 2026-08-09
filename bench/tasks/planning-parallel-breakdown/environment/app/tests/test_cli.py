import contextlib
import io
import json
import os
import tempfile
import unittest

from app.cli import main
from app.reports import usage_summary
from app.storage import Storage


class CliTests(unittest.TestCase):
    def setUp(self):
        fd, self.db = tempfile.mkstemp(suffix=".sqlite3")
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

    def test_summary_counts(self):
        self.run_cli("user", "create", "ada@example.com", "Ada")
        self.run_cli("project", "create", "Apollo", "1")
        summary = json.loads(self.run_cli("summary"))
        self.assertEqual(summary["users"], 1)
        self.assertEqual(summary["projects"], 1)

    def test_usage_summary_empty(self):
        storage = Storage(self.db + ".empty")
        self.assertEqual(usage_summary(storage)["projects"], 0)


if __name__ == "__main__":
    unittest.main()
