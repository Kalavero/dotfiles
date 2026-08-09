---
name: migration-safety
description: >
  Review database migrations for production safety. Use when writing or reviewing schema
  migrations (e.g. files under db/migrate) or any DDL change, especially on Postgres. Use when
  a migration touches large tables, adds indexes or constraints, or changes column types.
---

# Migration Safety

Check schema changes for operations that lock tables, block deploys, or cannot be rolled back. Postgres-focused; the locking rules differ on other databases.

If the project uses a migration linter (e.g. the `strong_migrations` gem — check the Gemfile), defer to its rules and help resolve its complaints rather than duplicating them.

## Checklist

Work through each item that applies to the migration under review:

### Locking and availability

- **Index creation** on an existing table must be `algorithm: :concurrently` (plus `disable_ddl_transaction!` in Rails). A plain `add_index` takes a lock that blocks writes for the whole build.
- **Adding a column with a volatile default** or a `NOT NULL` constraint validated immediately rewrites/scans the table. On modern Postgres (11+), constant defaults are safe; volatile ones are not. Add `NOT NULL` via a `CHECK ... NOT VALID` constraint, then `VALIDATE CONSTRAINT` separately.
- **Foreign keys**: add with `validate: false`, then validate in a separate migration — immediate validation scans both tables under lock.
- **Column type changes and renames** lock the table and break running code that still references the old shape. Use the expand/contract pattern: add new column, dual-write, backfill, switch reads, drop old column — each step its own deploy.
- **Anything on a large table**: estimate the table size first; an operation that is fine on 10k rows can take down production at 100M.

### Data and deploys

- **Backfills do not belong in schema migrations.** Move them to a separate data migration or background job, batched, with throttling.
- **Migration and code deploy ordering**: the schema change must be compatible with both the previous and the next version of the code (the migration runs while old code is still serving).
- **Rollback path**: every migration needs a working `down` (or an explicit, stated reason it is irreversible). Test the reversal mentally: does `down` restore both schema and any moved data?

### Review output

For each finding, state: the operation, why it is unsafe (what locks or breaks), and the concrete safe alternative. If everything checks out, say so explicitly — including which items were checked.
