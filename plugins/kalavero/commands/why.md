---
description: Explain why a piece of code exists — trace its history through commits, PRs, and tickets
---

`$ARGUMENTS` is a file path, a `path:line` reference, or a symbol name to investigate.

### 1. Walk the history

- For a line or small range: `git log -L <start>,<end>:<file>` to follow the code through edits.
- For a file: `git log --follow -p -- <file>` for renames and moves; add `-w` to skip whitespace-only changes.
- For code that moved between files: pickaxe with `git log -S "<distinctive snippet>" --all`.
- `git blame -w -C -C` on the current state to attribute surviving lines past refactors and copies.

Identify the commits that *introduced* the behavior, not just the last ones to touch the lines — blame often points at a rename or formatting commit; keep digging past those.

### 2. Find the surrounding context

- For each introducing commit, find its PR: `gh pr list --search "<sha>" --state merged` (or the PR reference in the merge commit message).
- Read the PR description and review discussion for intent.
- If a ticket is referenced (in the branch name, commit message, or PR body) and a tracker MCP is connected, pull the ticket for the original requirement.

### 3. Tell the story

Output a short narrative answering:

- **What it does** — one or two sentences on the code's current role.
- **Why it exists** — the original problem or requirement that introduced it, with commit/PR/ticket references.
- **How it evolved** — significant changes since, and why, if any.
- **Caveats** — anything that looks vestigial, load-bearing-but-undocumented, or worth verifying with the original author.

Ground every claim in something you actually found — a commit, PR, or ticket. Where the history is silent, say so rather than inventing a rationale.
