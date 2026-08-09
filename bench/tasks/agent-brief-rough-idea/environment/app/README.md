# exportly

A tiny CLI that exports per-account usage records to CSV for billing and
customer success.

## Usage

```sh
python -m exportly export --account acct-123 --month 2026-07 --db usage.db --out export.csv
```

The CSV column order is contractual — billing's invoicing system imports this
file. Do not reorder, rename, or reformat columns.

## Development

The project is stdlib-only; the only dev dependency is pytest.

```sh
python -m pytest
```
