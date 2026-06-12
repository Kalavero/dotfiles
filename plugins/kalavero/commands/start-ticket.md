---
description: Start work on a ticket — fetch it, summarize requirements, move it to In Progress, and create a branch
---

`$ARGUMENTS` is a ticket ID (e.g. `ABC-123`, `#456`) or a ticket URL from any tracker.

### 1. Discover the tracker

- If a tracker MCP is connected (Linear, Jira, or similar), use it.
- Else if the ticket looks like a GitHub issue (`#456` or a github.com URL), use `gh issue view`.
- Else ask the user where the ticket lives.

### 2. Fetch and summarize

Pull the ticket and present a tight summary:

- **Goal**: what the ticket asks for, in 1-2 sentences
- **Acceptance criteria**: as stated, or "none stated" if missing
- **Context from comments**: decisions, constraints, or links worth knowing
- **Open questions**: anything ambiguous that should be clarified before coding

Ask the user to confirm the summary matches their understanding before proceeding.

### 3. Set up

- If the tracker supports status, move the ticket to "In Progress" (or its equivalent)
- Discover the branch naming convention from recent branches (`git branch -a --sort=-committerdate | head -20`); create a branch for this ticket following it. If no convention is detectable, propose `<ticket-id>-<short-slug>` and confirm.

### 4. Suggest the next step

Based on the ticket's size:

- Small, well-defined change — start implementing directly
- Needs task breakdown — suggest `/kalavero:plan`
- Large or design-heavy — suggest `/kalavero:tad` first
- A bug — suggest `/kalavero:fix-bug`
