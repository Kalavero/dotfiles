import unittest

from app.models import Project, User


class ModelTests(unittest.TestCase):
    def test_user_roundtrip(self):
        user = User(id=1, email="ada@example.com", name="Ada")
        data = user.to_dict()
        self.assertEqual(data["email"], "ada@example.com")
        self.assertIn("created_at", data)

    def test_project_roundtrip(self):
        project = Project(id=1, name="Apollo", owner_id=1)
        self.assertEqual(project.to_dict()["owner_id"], 1)


if __name__ == "__main__":
    unittest.main()
