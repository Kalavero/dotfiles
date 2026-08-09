import pytest

import seed


@pytest.fixture()
def db_path(tmp_path):
    """A fresh seeded database for each test."""
    return seed.build_db(str(tmp_path / "test.db"))
