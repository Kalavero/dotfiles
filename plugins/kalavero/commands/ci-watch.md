---
description: Watch the current branch's CI run and, on failure, diagnose and fix until it goes green
---

`$ARGUMENTS` is optional: a PR number or branch (default: the current branch).

**Goal:** a green CI run for the branch.

**Stop conditions** (any one ends the loop): CI passes; the same failure survives two fix attempts; or the failure is outside the code (flaky infra, missing secret, env-only). On a non-green stop, escalate with the logs and your diagnosis — don't loop indefinitely.

### Loop

1. **Discover the host** at runtime: GitHub via `gh`. Find the latest run for the branch (`gh run list --branch`, `gh pr checks`).
2. **Watch it to completion** (`gh run watch`).
3. **If green**, report success and stop.
4. **If failing:**
   - Pull the failing job logs (`gh run view --log-failed`).
   - Reproduce locally where possible by running the same command/test the failing step ran, following the kalavero:debugging-and-error-recovery skill.
   - Fix the root cause. If it's purely a CI-environment failure (not reproducible locally), say so and propose the config fix rather than guessing at code.
   - Commit and push the fix — ask first if the branch is shared or protected — which triggers a new run.
5. **Re-watch and repeat**, honoring the stop conditions.

### Rules

- Distinguish a real failure from a flake: if a re-run passes with no code change, flag it as flaky and suggest `/kalavero:flaky-spec` rather than claiming a fix.
- Push only the fix for the failure at hand — no unrelated changes riding along on a CI-debugging push.
