import os
import sqlite3
import tempfile
import unittest

from app.storage import Storage


class StorageTests(unittest.TestCase):
    def setUp(self):
        fd, self.db = tempfile.mkstemp(suffix=".sqlite3")
        os.close(fd)
        os.unlink(self.db)  # let Storage create it fresh
        self.storage = Storage(self.db)

    def test_migrations_applied(self):
        with sqlite3.connect(self.db) as conn:
            tables = {
                row[0]
                for row in conn.execute(
                    "SELECT name FROM sqlite_master WHERE type = 'table'"
                )
            }
        self.assertIn("users", tables)
        self.assertIn("projects", tables)
        self.assertIn("schema_migrations", tables)

    def test_insert_get_all(self):
        user = self.storage.insert("users", {"email": "a@x.com", "name": "A"})
        self.assertEqual(user["id"], 1)
        self.assertEqual(self.storage.get("users", 1)["name"], "A")
        self.assertEqual(len(self.storage.all("users")), 1)
        self.assertIsNone(self.storage.get("users", 99))


if __name__ == "__main__":
    unittest.main()
