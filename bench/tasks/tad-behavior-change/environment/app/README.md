# orders

A minimal stdlib-only order service: an order state machine, a service layer
with immediate cancellation, a refund client wrapper, JSON-file persistence,
and a small WSGI API.

## Layout

- `orders/models.py` — Order dataclass, statuses, legal transitions
- `orders/service.py` — order operations, including today's immediate cancel
- `orders/refunds.py` — thin wrapper over the payment provider's refund API
- `orders/store.py` — JSON-file-backed order persistence
- `orders/api.py` — WSGI endpoints
- `tests/` — unittest suite

## Run

```
python -m orders.api
```

## Test

```
python -m unittest discover -s tests
```
