#!/bin/bash
# Oracle for debugging-race-under-load: reproduce the oversell under load,
# fix the read-modify-write race in inventory.py with a lock, add a
# regression test, and verify (load test 3x + full suite).
set -euo pipefail
cd /app

echo "== step 1: reproduce the failure under load =="
reproduced=0
for i in 1 2 3; do
  if python3 -m pytest tests/test_load.py -q > "/tmp/repro_$i.txt" 2>&1; then
    echo "run $i: passed (race window not hit this time)"
  else
    echo "run $i: FAILED — reproduced"
    reproduced=1
  fi
done
if [ "$reproduced" != "1" ]; then
  echo "ERROR: could not reproduce the oversell in 3 load runs" >&2
  exit 1
fi
grep -h -m1 "oversold" /tmp/repro_*.txt || true

echo "== step 2: localize — purchase() reads, validates, then writes with no guard =="
grep -n "_store\[sku\] = current - qty" inventory.py

echo "== step 3: fix the root cause — make check-and-decrement atomic =="
cat > inventory.py <<'EOF'
"""Inventory store: in-memory stock levels with purchase operations."""

import threading

_store = {}
_store_lock = threading.Lock()


def reset_inventory(items=None):
    """Reset the store to the given items (or the default demo stock)."""
    with _store_lock:
        _store.clear()
        _store.update(items or {"WIDGET": 100})


def stock(sku):
    """Current stock level for sku."""
    with _store_lock:
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
    with _store_lock:
        current = _store.get(sku, 0)
        if current < qty:
            return False
        _validate_order(sku, qty)
        _store[sku] = current - qty
        return True
EOF

echo "== step 4: add a regression test exercising concurrent purchases =="
cat > tests/test_concurrent_oversell_regression.py <<'EOF'
"""Regression test: concurrent purchases oversold the stock because
purchase() did a read-modify-write on the shared store with no lock."""

import threading

import inventory


def test_concurrent_purchases_never_oversell():
    initial = 40
    inventory.reset_inventory({"WIDGET": initial})
    sold = [0] * 20

    def worker(index):
        count = 0
        while inventory.purchase("WIDGET"):
            count += 1
        sold[index] = count

    threads = [threading.Thread(target=worker, args=(i,)) for i in range(20)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    total = sum(sold)
    assert total <= initial, f"oversold: {total} units sold of {initial} in stock"
    assert inventory.stock("WIDGET") == initial - total
EOF

echo "== step 5: write the cause summary =="
cat > CAUSE.md <<'EOF'
# Root cause: read-modify-write race in inventory.purchase

purchase() read the stock level, ran order validation, then wrote back
`current - qty` with nothing guarding the critical section. Under thread
load two threads could read the same level and both write it back, so more
units were reported sold than were ever in stock. Single-threaded tests
never interleave, which is why only the load test failed — and only when
the scheduler happened to switch threads inside the window, hence the
intermittent CI failure.

Fix: hold a threading.Lock around the whole check-and-decrement so the
read-modify-write is atomic. Adding sleeps would only narrow the race
window; retrying or weakening the load test would hide the symptom.
EOF

echo "== step 6: verify — load test 3x, then the full suite =="
for i in 1 2 3; do
  python3 -m pytest tests/test_load.py -q
done
python3 -m pytest tests -q
