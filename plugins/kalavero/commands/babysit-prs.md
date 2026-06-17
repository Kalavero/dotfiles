---
description: Check your open PRs for anything blocking them — CI failures, review comments, conflicts, ready-to-merge
---

Surface every open PR that needs your attention and confirm the rest are unblocked. Designed to run once or on an interval (e.g. `/loop 10m /kalavero:babysit-prs`).

**Goal:** a clear picture of which PRs are blocked, on what, and which are ready to merge.

Read-only by default — never merge, comment, close, or push without explicit confirmation.

### Steps

1. **Discover the host** at runtime: GitHub via `gh`. If a tracker MCP is connected, enrich each PR with its linked ticket's status.
2. **List your PRs**: `gh pr status` plus `gh search prs --author @me --state open` for ones outside the current repo.
3. **Classify each PR:**
   - **CI failing** — name the failing checks (`gh pr checks`); suggest `/kalavero:ci-watch` to drive it green.
   - **Review activity** — changes requested, or new comments since your last push; summarize what's being asked.
   - **Conflicts / out of date** with the base branch.
   - **Ready to merge** — approved, checks green, mergeable.
   - **Waiting** — draft or CI still running; note, no action.
4. **Output a compact status board** grouped into "Needs action", "Waiting", and "Ready to merge" — one line per PR with the specific blocker and a suggested next step.

### Under `/loop`

Highlight only what changed since the previous run (new failures, new comments, newly mergeable) so repeated runs stay quiet when nothing moved. Still never act without confirmation.
