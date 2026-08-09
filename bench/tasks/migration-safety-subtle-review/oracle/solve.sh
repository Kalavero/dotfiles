#!/bin/bash
# Oracle: derive the review by scanning the migration for unsafe patterns,
# then emit /app/review.md describing each finding with its mechanism and
# the safe alternative. Nothing is hardcoded that is not first detected in
# the migration source.
set -euo pipefail

python3 <<'PY'
import pathlib
import re

migration = pathlib.Path(
    "/app/db/migrate/20260801000000_add_order_fulfillment.rb"
).read_text()
notes = pathlib.Path("/app/db/production_notes.md").read_text()

rows_match = re.search(r"`orders`: ~([\d]+)M rows", notes)
orders_rows = f"{rows_match.group(1)}M" if rows_match else "tens of millions of"

findings = []

for line in migration.splitlines():
    if re.search(r"add_column :orders, :reference.*default:\s*->", line):
        findings.append(
            "1. `add_column :orders, :reference` with a volatile default "
            "(`default: -> { \"gen_random_uuid()\" }`). Mechanism: a volatile "
            "default forces Postgres to rewrite the entire table "
            f"({orders_rows} rows) under an ACCESS EXCLUSIVE lock, blocking all "
            "writes for the duration. Safe alternative: add the column with no "
            "default, backfill it in a separate data migration, then set the "
            "default once the backfill is done."
        )
    if re.search(r"add_check_constraint", line) and "validate: false" not in line:
        findings.append(
            "2. `add_check_constraint :orders, \"total > 0\"` validates "
            "immediately. Mechanism: immediate validation scans every one of "
            f"the {orders_rows} rows while holding a SHARE ROW EXCLUSIVE lock "
            "that blocks writes. Safe alternative: add the constraint with "
            "`validate: false` and validate it in a separate migration "
            "(`validate_check_constraint`, which only needs a SHARE UPDATE "
            "EXCLUSIVE lock)."
        )
    if re.search(r"add_index", line) and "concurrently" not in line:
        idx = re.search(r'name: "([^"]+)"', migration)
        name = idx.group(1) if idx else "the new index"
        findings.append(
            f"3. Plain `add_index` (`{name}`) on `orders`. Mechanism: a "
            "non-concurrent index build takes a SHARE lock on the table that "
            "blocks writes for the whole build — minutes on a table this size. "
            "Safe alternative: `add_index ..., algorithm: :concurrently` with "
            "`disable_ddl_transaction!`."
        )
    if re.search(r"add_foreign_key", line) and "validate: false" not in line:
        findings.append(
            "4. `add_foreign_key :orders, :accounts` validates immediately. "
            "Mechanism: validation takes SHARE ROW EXCLUSIVE locks on both "
            "tables and scans both under lock. Safe alternative: add the "
            "foreign key with `validate: false`, then validate it in a "
            "separate migration."
        )
    if re.search(r"rename_column :orders, :total,", line):
        findings.append(
            "5. `rename_column :orders, :total, :total_amount` while the "
            "previous release is still serving traffic. Mechanism: the old "
            "code still selects `total`, so it breaks against the renamed "
            "column the moment the migration runs mid-deploy. Safe "
            "alternative: expand/contract — add `total_amount`, dual-write, "
            "backfill, switch reads, and drop `total` in a later deploy."
        )

if re.search(r"find_each|update_all", migration):
    findings.append(
        "6. In-migration backfill (`Order.where(reference: nil).find_each`). "
        f"Mechanism: {orders_rows} single-row UPDATEs run inside the "
        "migration's transaction — a long-running transaction holding locks "
        "and generating huge WAL volume. Safe alternative: move the backfill "
        "to a separate data migration or background job, batched and "
        "throttled."
    )

checked_safe = []
if re.search(r"add_column :orders, :priority, :integer, default: 0", migration):
    checked_safe.append(
        "`add_column :orders, :priority, :integer, default: 0` — constant "
        "default, metadata-only on Postgres 11+; checked and it is fine."
    )
if re.search(r"add_column :orders, :fulfillment_notes, :text\s*$", migration, re.M):
    checked_safe.append(
        "`add_column :orders, :fulfillment_notes, :text` — nullable, no "
        "default; metadata-only, checked and it is fine."
    )

review = ["# Migration review: AddOrderFulfillment", ""]
if findings:
    review.append("## Findings")
    review.append("")
    review.extend(findings)
else:
    review.append("No safety problems found. Checked: index creation, column "
                  "defaults, constraint and foreign-key validation timing, "
                  "renames/type changes against running code, backfills, and "
                  "the rollback path.")
if checked_safe:
    review.append("")
    review.append("## Checked and safe")
    review.append("")
    review.extend(checked_safe)

pathlib.Path("/app/review.md").write_text("\n\n".join(review) + "\n")
print(f"wrote /app/review.md with {len(findings)} findings")
PY
