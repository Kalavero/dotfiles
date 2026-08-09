import os
import tempfile
import unittest

from app.storage import Storage


class StorageTests(unittest.TestCase):
    def setUp(self):
        fd, self.db = tempfile.mkstemp(suffix=".json")
        os.close(fd)
        os.unlink(self.db)  # let Storage create it fresh
        self.storage = Storage(self.db)

    def test_insert_assigns_incrementing_ids(self):
        first = self.storage.insert("users", {"email": "a@x.com", "name": "A"})
        second = self.storage.insert("users", {"email": "b@x.com", "name": "B"})
        self.assertEqual(first["id"], 1)
        self.assertEqual(second["id"], 2)

    def test_get_and_all(self):
        self.storage.insert("projects", {"name": "Apollo", "owner_id": 1})
        self.assertEqual(len(self.storage.all("projects")), 1)
        self.assertEqual(self.storage.get("projects", 1)["name"], "Apollo")
        self.assertIsNone(self.storage.get("projects", 99))


if __name__ == "__main__":
    unittest.main()
