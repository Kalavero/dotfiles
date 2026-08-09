import json
import os
import tempfile
import unittest

from app.auth import AuthError, authenticate
from app.store import Store


class AuthenticateTest(unittest.TestCase):
    def setUp(self):
        self.data_dir = tempfile.mkdtemp()
        self.store = Store(self.data_dir)
        with open(os.path.join(self.data_dir, "api_keys.json"), "w") as fh:
            json.dump({"k-pro": {"tier": "pro", "owner": "ada"}}, fh)

    def test_valid_key_returns_tier(self):
        caller = authenticate({"HTTP_X_API_KEY": "k-pro"}, self.store)
        self.assertEqual(caller["tier"], "pro")
        self.assertEqual(caller["owner"], "ada")

    def test_missing_key_rejected(self):
        with self.assertRaises(AuthError):
            authenticate({}, self.store)

    def test_unknown_key_rejected(self):
        with self.assertRaises(AuthError):
            authenticate({"HTTP_X_API_KEY": "nope"}, self.store)


if __name__ == "__main__":
    unittest.main()
