# Technical approach: Scheduled report exports

Status: approved
Author: Priya Nair
Date: 2026-07-28

## Problem

Customer success managers export usage reports by hand every Monday morning.
Each export takes them through the same five-click flow, and the Monday batch
regularly gets forgotten during on-call weeks. Two enterprise accounts have
asked for the report to simply arrive in their inbox on a schedule.

## Approach

Add scheduled exports. A user picks a report kind, a weekday, and a recipient
email address; a weekly job renders the CSV with the existing
`ReportRenderer`, uploads it to the exports bucket, and emails a signed
download link that expires after seven days. Schedules live in a new
`export_schedules` table. No new external services; we reuse the bucket and
the transactional mailer we already run. While we're in here, we also clean
up the reports-page button terminology so the UI matches the feature name.

## Proposed tasks

### Task 1: Create the `export_schedules` table migration (1 point)

Add a migration creating `export_schedules` with columns `id`, `account_id`,
`report_kind`, `weekday`, `recipient_email`, and `created_at`, plus an index
on `weekday` for the scheduler lookup. This is a metadata-only change with no
backfill; follow the existing migration conventions in `db/migrate`.

### Task 2: Build the schedule CRUD API endpoints (3 points)

Add REST endpoints to create, list, update, and delete export schedules for
the caller's account, with request validation (known report kinds, weekday in
0–6, syntactically valid email) and request specs. Follow the conventions of
the existing `ReportsController`, including its error envelope and
authorization checks.

### Task 3: Implement the export generation job

Add a background job that, given a schedule ID, renders the report CSV via
`ReportRenderer`, uploads it to the exports bucket under a deterministic key,
and records a signed URL with a seven-day expiry. The job must be idempotent
per schedule and weekday so a retry never double-delivers, and it needs its
own retry and alerting semantics so a transient bucket failure doesn't
silently drop a customer's export.

### Task 4: Add email delivery for completed exports (2 points)

Send the schedule's recipient a "your export is ready" email containing the
signed URL, using the existing `TransactionalMailer` and its layout. Include
a mailer preview and a spec covering the URL expiry copy.

### Task 5: Wire the weekly scheduler with missed-day catch-up

Register the weekly cron entry that enqueues the generation job for every
schedule whose weekday matches the current day. The scheduler has to handle
the messy cases: catch-up runs for schedules missed while the worker was
down, jitter so hundreds of accounts don't render in the same minute, and an
ops runbook entry covering the schedule, the retry behavior, and how to
re-run a missed day by hand.

### Task 6: Rename the reports-page export button

The reports page still says "Download" on the button that produces a CSV.
Rename it to "Export CSV" so the terminology matches the scheduled-exports
feature, and update the one snapshot test that asserts the label.

## Sequencing

Everything builds on the migration: the CRUD endpoints and the export
generation job both read and write the new table, so neither can start before
the migration lands. The exporter tickets can only start once the migration
is in, and email delivery additionally needs the generation job, because the
email carries the job's signed download URL. The scheduler wires the whole
feature together and goes last — schedules have to be creatable through the
endpoints before there is anything to run, and the email path needs to be
live before the scheduler enqueues real customer work. The button rename is
independent of all of this and can ship whenever someone has a spare moment.

## Open questions

None — approved as written.
