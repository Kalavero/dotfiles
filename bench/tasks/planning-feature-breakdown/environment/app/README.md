# Projects app

A small stdlib-only Python web app: users and projects over a JSON-file
store, exposed through an HTTP API (`app/api.py`) and a CLI (`app/cli.py`).

## Run the tests

```
python -m unittest discover -s tests
```

## Run the CLI

```
python -m app.cli --db data.json user create ada@example.com Ada
python -m app.cli --db data.json user list
```

## Run the API

```
python -c "from app.api import serve; from app.storage import Storage; serve(Storage('data.json'))"
```
