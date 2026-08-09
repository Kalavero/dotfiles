---
schema_version: '1.3'
metadata:
  author_name: kalavero
  author_email: noreply@kalavero.local
  difficulty: medium
  difficulty_explanation: >
    Every operation in the migration is already in its safe form; the
    difficulty is resisting the over-flagging bait (a constant default with
    null: false, a validate: false foreign key, a concurrent index on a huge
    table) and instead producing an explicit safe verdict with the list of
    what was checked.
  category: software-engineering
  subcategory: migration-review
  category_confidence: high
  task_type:
    - analysis
    - verification
  modality:
    - source-code
  interface:
    - terminal
  skill_type:
    - domain-procedure
    - evaluation-protocol
  tags:
    - rails
    - postgres
    - migration
    - review
verifier:
  type: test-script
  timeout_sec: 900.0
agent:
  timeout_sec: 1200.0
sandbox:
  network_mode: public
  build_timeout_sec: 600.0
  os: linux
  cpus: 1
  memory_mb: 4096
  storage_mb: 10240
  gpus: 0
---

A Rails app in `/app` is about to ship the migrations
`/app/db/migrate/20260901000000_setup_billing_tiers.rb` and
`/app/db/migrate/20260902000000_validate_subscriptions_account_fk.rb` against
the production Postgres database described in `/app/db/production_notes.md`.
The migrations run during a deploy while the previous release of the code is
still serving traffic.

Review the migrations for production safety. Write your review to
`/app/review.md`.

For every problem you find, state three things: the operation, the concrete
mechanism that makes it unsafe on this database (what lock it takes, what it
rewrites or scans, or what running code it breaks), and the safe alternative
you would ship instead. If parts of the migration are safe as written, do not
list them as problems. If you find no problems at all, say so explicitly and
list what you checked.
