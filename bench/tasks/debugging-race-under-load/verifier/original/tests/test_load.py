"""Load harness: hammer purchase() from many threads and check we never
sell more units than we had in stock."""

import threading

import inventory

INITIAL_STOCK = 100
THREADS = 50


def test_no_oversell_under_load():
    inventory.reset_inventory({"WIDGET": INITIAL_STOCK})
    sold = [0] * THREADS

    def worker(index):
        count = 0
        while inventory.purchase("WIDGET"):
            count += 1
        sold[index] = count

    threads = [threading.Thread(target=worker, args=(i,)) for i in range(THREADS)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    total = sum(sold)
    assert total <= INITIAL_STOCK, f"oversold: {total} units sold of {INITIAL_STOCK} in stock"
    assert inventory.stock("WIDGET") == INITIAL_STOCK - total
