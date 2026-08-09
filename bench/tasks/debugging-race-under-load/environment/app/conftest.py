import pytest

import inventory


@pytest.fixture(autouse=True)
def fresh_inventory():
    inventory.reset_inventory()
    yield
