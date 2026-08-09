# Projects app

A small stdlib-only Python web app: users and projects over SQLite with
file-based migrations, exposed through an HTTP API (`app/api.py`) and a
CLI (`app/cli.py`).

## Run the tests

```
python -m unittest discover -s tests
```

## Run the CLI

```
python -m app.cli --db data.sqlite3 user create ada@example.com Ada
python -m app.cli --db data.sqlite3 summary
```

## Run the API

```
python -c "from app.api import serve; from app.storage import Storage; serve(Storage('data.sqlite3'))"
```
