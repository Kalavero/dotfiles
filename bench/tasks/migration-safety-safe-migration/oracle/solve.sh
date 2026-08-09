#!/bin/bash
# Oracle: derive the review by parsing the migrations and checking that each
# operation is present in its safe form (concurrent index, deferred FK
# validation, constant default, no renames, no backfills, working down).
# Any operation found in an unsafe form becomes a finding instead; only when
# every check passes does the oracle emit the "no problems" verdict with the
# list of what was checked. Nothing is asserted that is not first detected
# in the migration source.
set -euo pipefail

python3 <<'PY'
import pathlib
import re

migration = pathlib.Path(
    "/app/db/migrate/20260901000000_setup_billing_tiers.rb"
).read_text()
validate_migration = pathlib.Path(
    "/app/db/migrate/20260902000000_validate_subscriptions_account_fk.rb"
).read_text()
notes = pathlib.Path("/app/db/production_notes.md").read_text()

pg_match = re.search(r"Postgres (\d+)", notes)
pg_major = int(pg_match.group(1)) if pg_match else 0

rows_match = re.search(r"`subscriptions`: ~([\d]+)M rows", notes)
subs_rows = f"{rows_match.group(1)}M" if rows_match else "tens of millions of"

findings = []
checked = []

# --- Index creation -------------------------------------------------------
idx_call = re.search(r"add_index.{0,200}", migration, re.S)
if idx_call:
    if re.search(r"algorithm:\s*:concurrently", idx_call.group(0)) and re.search(
        r"disable_ddl_transaction!", migration
    ):
        checked.append(
            "Index creation: `idx_subscriptions_account_plan` is built with "
            "`algorithm: :concurrently` and `disable_ddl_transaction!`, so "
            f"the build does not block writes on `subscriptions` (~{subs_rows} "
            "rows)."
        )
    else:
        findings.append(
            "- `add_index` on `subscriptions` without `algorithm: "
            f":concurrently`: a non-concurrent build takes a SHARE lock that "
            f"blocks writes for the whole build (~{subs_rows} rows). Safe "
            "alternative: `algorithm: :concurrently` plus "
            "`disable_ddl_transaction!`."
        )

# --- Foreign key validation timing -----------------------------------------
fk_line = re.search(r"add_foreign_key[^\n]*", migration)
if fk_line:
    if re.search(r"validate:\s*false", fk_line.group(0)) and re.search(
        r"validate_foreign_key\s+:subscriptions,\s+:accounts", validate_migration
    ):
        checked.append(
            "Foreign key validation timing: `add_foreign_key :subscriptions, "
            ":accounts, validate: false` defers validation, and the separate "
            "migration `20260902000000_validate_subscriptions_account_fk.rb` "
            "runs `validate_foreign_key`, which only needs a SHARE UPDATE "
            "EXCLUSIVE lock and does not block writes."
        )
    else:
        findings.append(
            "- `add_foreign_key :subscriptions, :accounts` without deferred "
            "validation: immediate validation takes SHARE ROW EXCLUSIVE locks "
            "on both tables and scans them under lock. Safe alternative: "
            "`validate: false` plus a separate `validate_foreign_key` "
            "migration."
        )

# --- Column defaults --------------------------------------------------------
plan_line = re.search(r"add_column :subscriptions, :plan_code[^\n]*", migration)
if plan_line:
    default_match = re.search(r"default:\s*([^,]+)", plan_line.group(0))
    default = default_match.group(1).strip() if default_match else None
    constant = default is not None and "->" not in default
    if constant and pg_major >= 11:
        checked.append(
            "Column defaults: `add_column :subscriptions, :plan_code, "
            ':string, default: "free", null: false` uses a constant default, '
            f"which is metadata-only on Postgres 11+ (production runs "
            f"Postgres {pg_major}) — no table rewrite, no per-row scan, and "
            "the NOT NULL is satisfied by the default."
        )
    elif not constant:
        findings.append(
            "- `add_column :subscriptions, :plan_code` with a volatile "
            "default: Postgres must rewrite the entire table under an ACCESS "
            "EXCLUSIVE lock. Safe alternative: add the column without a "
            "default, backfill separately, then set the default."
        )
    else:
        findings.append(
            "- `add_column :subscriptions, :plan_code` with a default on "
            f"Postgres {pg_major}: pre-11 Postgres rewrites the table for "
            "constant defaults. Safe alternative: add without default, "
            "backfill, then set the default."
        )

for col in ("billing_interval", "trial_ends_at"):
    col_line = re.search(rf"add_column :subscriptions, :{col}[^\n]*", migration)
    if col_line and "default" not in col_line.group(0):
        checked.append(
            f"Nullable column: `add_column :subscriptions, :{col}` has no "
            "default and no NOT NULL — metadata-only, no rewrite or scan."
        )

# --- Renames / type changes vs running code ---------------------------------
if re.search(r"rename_column|rename_table|change_column\b", migration):
    findings.append(
        "- A rename or type change runs while the previous release still "
        "serves traffic: old code referencing the old column shape breaks "
        "mid-deploy. Safe alternative: expand/contract — add the new column, "
        "dual-write, backfill, switch reads, drop the old column in a later "
        "deploy."
    )
else:
    checked.append(
        "Renames and type changes: none present. `billing_interval` is a new "
        "column added alongside the existing schema (expand step), so running "
        "code from the previous release keeps working."
    )

# --- Backfills ---------------------------------------------------------------
if re.search(r"find_each|update_all|update_columns|in_batches|\.each do", migration):
    findings.append(
        "- In-migration data backfill: row updates inside the migration "
        "transaction mean a long-running transaction holding locks and "
        "generating WAL on a huge table. Safe alternative: separate data "
        "migration or background job, batched and throttled."
    )
else:
    checked.append(
        "Backfills: none present — the migration contains no data backfill "
        "and no model-level update loops."
    )

# --- Rollback path ------------------------------------------------------------
down_match = re.search(r"def down(.*?)end\s*$", migration, re.S)
down_body = down_match.group(1) if down_match else ""
missing_down = [
    op
    for op in ("remove_index", "remove_foreign_key", "remove_column")
    if op not in down_body
]
if down_match and not missing_down:
    checked.append(
        "Rollback path: `down` removes the foreign key, the index, and all "
        "three added columns, so the migration is fully reversible."
    )
else:
    findings.append(
        "- Rollback path: `down` is missing or incomplete (missing: "
        f"{', '.join(missing_down) or 'def down'}), so the migration cannot "
        "be cleanly reversed. Safe alternative: implement the matching "
        "remove_* calls."
    )

review = ["# Migration review: SetupBillingTiers", ""]
if findings:
    review.append("## Findings")
    review.append("")
    review.extend(findings)
    if checked:
        review.append("")
        review.append("## Checked and safe")
        review.append("")
        review.extend(f"- {c}" for c in checked)
else:
    review.append("## Verdict")
    review.append("")
    review.append(
        "No production-safety problems found — these migrations are safe to "
        "ship as written."
    )
    review.append("")
    review.append("## What was checked")
    review.append("")
    review.extend(f"- {c}" for c in checked)

pathlib.Path("/app/review.md").write_text("\n".join(review) + "\n")
print(f"wrote /app/review.md with {len(findings)} findings, {len(checked)} checks")
PY
