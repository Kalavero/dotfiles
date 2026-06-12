---
description: Create a draft PR — repo template, linked ticket, diff summary, and test plan
---

`$ARGUMENTS` is optional context (a ticket ID, or notes to include in the description).

### 1. Discover conventions

- Read `.github/PULL_REQUEST_TEMPLATE.md` (or `.github/pull_request_template.md`, or `docs/`) if present — its structure takes precedence over the fallback below.
- Look at 3-5 recent merged PRs (`gh pr list --state merged --limit 5`) to learn how this repo links tickets: closing keywords, tracker magic words, or plain links.
- Infer the ticket from the current branch name if `$ARGUMENTS` didn't provide one.

### 2. Draft the description

Summarize the diff against the default branch (`git diff <default-branch>...HEAD`), then fill the template. If no template exists, use:

```markdown
## What

<1-3 sentences: what changed and why>

<ticket link, using the convention discovered above>

## How

<bullets on the approach, only where the diff doesn't speak for itself>

## Test plan

- [ ] <how this was verified — commands run, manual checks>

## Screenshots

<before/after for UI changes; remove this section otherwise>
```

Keep it honest: only list test-plan items that were actually performed or that the reviewer should perform.

### 3. Confirm and create

- Show the user the title and full description; iterate until approved.
- Create as a draft: `gh pr create --draft`. Only mark ready for review if the user asks.
