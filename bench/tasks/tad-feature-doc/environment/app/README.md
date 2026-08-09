# widget-api

A minimal stdlib-only WSGI API for managing a widget inventory. Callers
authenticate with an `X-Api-Key` header; each key has a tier.

## Layout

- `app/server.py` — WSGI application and routing
- `app/auth.py` — API-key authentication, resolves the caller's tier
- `app/store.py` — JSON-file-backed storage (widgets, API keys)
- `app/config.py` — environment-driven configuration
- `tests/` — unittest suite

## Run

```
python -m app.server
```

## Test

```
python -m unittest discover -s tests
```
