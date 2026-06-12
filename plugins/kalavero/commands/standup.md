---
description: Summarize recent work into standup notes — commits, PRs, ticket movement, blockers
---

`$ARGUMENTS` is optional: how many days back to look (default: since the last weekday).

### 1. Gather activity

- **Commits**: in the current repo (and sibling repos under the same parent directory if they show recent activity), `git log --author="$(git config user.email)" --since=<window> --oneline --all`.
- **PRs**: `gh search prs --author @me --updated ">=<date>"` for opened, updated, reviewed, and merged.
- **Tickets**: if a tracker MCP is connected, pull issues assigned to the user that changed status in the window.

### 2. Compose

Output ready to paste into chat:

```markdown
*Yesterday*
- <shipped/progressed item, with PR or ticket reference>

*Today*
- <in-flight work inferred from open PRs and In Progress tickets>

*Blockers*
- <only if evidence suggests one: a PR waiting on review for days, a ticket marked blocked. Otherwise "None">
```

Keep each bullet to one line, outcome-phrased ("Shipped X", "Fixed Y", not "Worked on Z"). Merge related commits into a single item. If the window spans a weekend, say "Friday" instead of "Yesterday".

### 3. Confirm

Show the draft. The "Today" section is a guess — ask the user to correct it before they paste.
