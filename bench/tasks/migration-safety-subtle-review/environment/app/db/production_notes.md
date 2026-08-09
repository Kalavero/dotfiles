# Production database notes

- Postgres 15.4, primary in us-east-1.
- `orders`: ~90M rows, ~400 writes/second sustained, peak ~1.2k/second.
- `accounts`: ~2M rows.
- Deploys are zero-downtime, rolling: while a migration runs, the previous
  release of the application code is still serving production traffic, and the
  new release boots against the migrated schema.
- The app runs Rails 7.1. There is no migration linting gem in the bundle.
