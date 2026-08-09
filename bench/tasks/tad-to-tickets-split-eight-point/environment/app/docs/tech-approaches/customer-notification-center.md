# Technical approach: Customer notification center

Status: approved
Author: Diego Ramirez
Date: 2026-07-30

## Problem

Customers miss important account events — failed payments, usage-limit
warnings, security alerts — because today they only surface inside the
product UI on the page where they happened. Support tickets asking "why
didn't anyone tell me?" are our third-largest category this quarter.

## Approach

Build a notification center: a persisted store of notifications per user, a
pipeline that turns domain events into notifications across channels (in-app
feed first, email second), per-user delivery preferences, and a daily digest
email for anything unread. We reuse the existing event bus and the
transactional mailer; no new vendor.

## Proposed tasks

### Task 1: Create the notifications schema migration (2 points)

Add a migration creating `notifications` (`id`, `user_id`, `kind`, `payload`
jsonb, `read_at`, `created_at`) with an index on `(user_id, created_at)` for
feed lookups, and `notification_preferences` (`user_id`, `channel`, `kind`,
`enabled`) with a uniqueness constraint on the triple. Metadata-only; no
backfill.

### Task 2: Build the notification preferences API (2 points)

Endpoints for reading and updating the current user's per-channel, per-kind
delivery preferences, with validation and request specs. Unknown kinds are
rejected; defaults come from a single `NotificationKind` registry so the API
and the pipeline never drift.

### Task 3: Build the notification pipeline (8 points)

The end-to-end pipeline: ingest domain events from the bus, render
notification content from per-kind templates, and deliver across channels
(in-app record plus email when enabled) with retries and idempotency keys.
This is high-complexity work with critical unknowns — we have not yet
measured event-volume shape at peak, and template rendering performance with
large payloads is unproven — so expect the plan to change as those unknowns
surface.

### Task 4: Add the in-app notification feed (5 points)

The feed API and UI: a paginated, newest-first list of the current user's
notifications with mark-as-read and an unread-count badge. The feed reads
straight from the pipeline's persistence layer; no second store. This is a
feature-spanning piece (API, UI, badge state) but the pattern is the one
established by the activity feed, so it is well understood.

### Task 5: Add the notification digest email job (3 points)

A daily job that emails each user a digest of their unread notifications,
honoring their preferences, reusing the pipeline's template rendering, and
skipping users with nothing unread. Includes a mailer preview and a spec for
the preference-filtering logic.

## Sequencing

- Task 1 has no dependencies and can start immediately.
- Task 2 depends on Task 1.
- Task 3 depends on Task 1.
- Task 4 depends on Task 3.
- Task 5 depends on Task 3.

## Open questions

None blocking — approved as written. Peak event-volume measurement is folded
into Task 3.
