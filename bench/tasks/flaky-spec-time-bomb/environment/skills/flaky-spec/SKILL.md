---
name: flaky-spec
description: >
  Hunt down and fix flaky tests. Use when a test passes and fails intermittently, fails only in
  CI, or fails only when the full suite runs but passes in isolation. Use when the user mentions
  a flaky, intermittent, or order-dependent test failure.
---

# Flaky Spec

Find the root cause of an intermittent test failure instead of retrying until green. Written for RSpec; adapt the commands to the project's test framework (discover it from the repo before starting).

## Phase 1 — Characterize the flake

Establish in which conditions the test fails. Run, in order:

1. **In isolation**: the single example (`rspec path/to/spec.rb:LINE`). Repeat several times.
2. **The full file**: `rspec path/to/spec.rb`.
3. **The full suite (or the failing CI subset)** with the seed from the failing run: `rspec --seed <seed>`.

Record the outcome of each. The pattern localizes the cause:

| Fails... | Likely cause |
|---|---|
| Even in isolation, intermittently | Time, randomness, async/race, or external dependency inside the test |
| Only with the full file | Shared state between examples (let/before misuse, class-level state) |
| Only in the suite, seed-dependent | Order-dependent leakage from another test |
| Only in CI | Environment: parallelism, timezone, resources, missing service, different DB state |

## Phase 2 — Localize

- **Order-dependent**: reproduce with the failing seed, then `rspec --seed <seed> --bisect` to find the minimal failing combination. The other test in the pair is usually the polluter.
- **Time-related**: grep the test and code under test for `Time.now`/`Date.today`/timezone assumptions; check whether the suite uses time-freezing helpers consistently.
- **Async/race**: look for sleeps, waits, jobs executed inline vs queued, and assertions that race a background thread or browser.
- **State leakage**: check for class variables, memoized singletons, global config mutated in tests, DB records surviving between examples (transaction vs truncation strategy), and stubs/mocks not cleaned up.
- **Network**: confirm external calls are stubbed; a test that sometimes hits the network is flaky by construction.

## Phase 3 — Fix and guard

- Fix the root cause, not the symptom: clean up the polluter, freeze time, await the condition instead of sleeping, stub the dependency. Do not add retries or longer sleeps as the fix.
- Re-run the previously failing scenario enough times to be convincing (including the failing seed for order issues).
- Where the cause was a polluter, consider whether the same leak affects other tests, and fix the source once rather than hardening one victim.
- State plainly in the summary what the root cause was and how the fix prevents recurrence.
