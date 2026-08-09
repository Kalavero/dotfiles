"""Single-threaded tests for the inventory store."""

import inventory


def test_purchase_decrements_stock():
    assert inventory.purchase("WIDGET", 3) is True
    assert inventory.stock("WIDGET") == 97


def test_purchase_fails_when_insufficient_stock():
    assert inventory.purchase("WIDGET", 101) is False
    assert inventory.stock("WIDGET") == 100


def test_unknown_sku_has_zero_stock():
    assert inventory.stock("NOPE") == 0
    assert inventory.purchase("NOPE") is False


def test_reset_inventory_restores_stock():
    inventory.purchase("WIDGET", 10)
    inventory.reset_inventory()
    assert inventory.stock("WIDGET") == 100
