import tempfile
import unittest

from app.store import Store


class StoreTest(unittest.TestCase):
    def setUp(self):
        self.store = Store(tempfile.mkdtemp())

    def test_missing_collection_reads_as_empty(self):
        self.assertEqual(self.store.list_widgets(), [])

    def test_create_and_get_widget(self):
        self.store.create_widget({"id": "w1", "name": "sprocket"})
        self.assertEqual(self.store.get_widget("w1")["name"], "sprocket")

    def test_unknown_widget_returns_none(self):
        self.assertIsNone(self.store.get_widget("nope"))


if __name__ == "__main__":
    unittest.main()
