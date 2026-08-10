---
description: Drive the test suite to green — run, diagnose failures, fix, re-run until passing
---

`$ARGUMENTS` is optional: a test path or pattern to scope to (default: the affected tests if a change is in progress, then the full suite).

**Goal:** a green test run.

**Stop conditions** (any one ends the loop): the suite passes; the failure set fails to shrink across two consecutive rounds; or a round cap is reached. On a non-green stop, report what's still failing and why, and escalate — never force green.

### Loop

1. **Discover the runner** from the repo (test directory, config, dependency manifest) and use the project's own command. If a change is in progress, run the affected tests first, then widen to the full suite once those pass.
2. **Run.** If green, go to step 5.
3. **Diagnose each distinct failure** — reproduce, localize, identify the root cause, and fix the cause.
4. **Re-run, and track the failure set.** If it isn't shrinking across two rounds, or you hit the round cap, stop and escalate. Otherwise repeat from step 2.
5. **Report:** what was failing, the root cause(s), and the fix(es). Do not commit unless asked.

### Rules

- Never make a test pass by weakening it — skipping, marking pending, loosening an assertion, or bumping a timeout as the "fix" is a false green. Flag it instead.
- A test that fails intermittently rather than deterministically is a flake, not a fix target — flag it rather than looping on it.
