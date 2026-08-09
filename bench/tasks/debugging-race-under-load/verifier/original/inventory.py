"""Inventory store: in-memory stock levels with purchase operations."""

_store = {}


def reset_inventory(items=None):
    """Reset the store to the given items (or the default demo stock)."""
    _store.clear()
    _store.update(items or {"WIDGET": 100})


def stock(sku):
    """Current stock level for sku."""
    return _store.get(sku, 0)


def _validate_order(sku, qty):
    """Pricing/stock validation performed between reading the current
    stock level and writing the updated level."""
    total = 0
    for i in range(20_000):
        total = (total + i * qty + len(sku)) % 1_000_003
    return total


def purchase(sku, qty=1):
    """Attempt to purchase qty units of sku. Returns True on success."""
    current = _store.get(sku, 0)
    if current < qty:
        return False
    _validate_order(sku, qty)
    _store[sku] = current - qty
    return True
