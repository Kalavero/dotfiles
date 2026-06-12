---
name: agent-brief
description: >
  Convert a rough task idea into an agent-ready brief. Use when delegating work to an AI coding
  agent (Claude Code, Cursor, Codex, or similar) and the task description is still rough, vague,
  or living in the user's head. Use when the user asks to write a brief, prompt, or task
  description for an agent.
---

# Agent Task Brief

Vague instructions are the leading cause of bad agent output. This skill turns a rough idea into a brief that an agent with zero conversation context could execute without follow-up questions.

## Phase 1 — Interview

Ask only what the rough idea leaves genuinely open (usually 2-4 questions):

- What does "done" look like? What would you check first to see if it worked?
- What must NOT change or break?
- Any approach you already have in mind, or want avoided?
- Where should the agent's output go (PR, branch, files, chat)?

Skip questions the codebase can answer — go look instead.

## Phase 2 — Ground it in the repo

Search the target repo before writing anything:

- The files and modules the task will touch, with paths.
- Existing patterns the agent should follow (a similar feature, an established idiom).
- Prior art to reuse rather than rebuild.
- The verification commands this project actually uses (test runner, linter, build).

Never fabricate paths or patterns. Everything cited in the brief must have been found.

## Phase 3 — Write the brief

```markdown
# Brief: <task title>

## Objective
<One sentence. The outcome, not the activity.>

## Context
- Relevant code: `<path>` — <why it matters>
- Follow the pattern in: `<path>` — <what to imitate>
- Reuse: `<existing function/util>` instead of writing new

## Constraints
- <what must not change; compatibility, performance, or convention requirements>

## Acceptance criteria
- [ ] <specific, testable condition — 3 to 7 total>

## Non-goals
- <explicitly out of scope, to prevent over-reach>

## Verification
- Run: `<exact commands — tests, build, lint>`
- Manual check: <what to observe>
```

## Phase 4 — Quality check

Before delivering, verify the brief stands alone:

- Could an agent that never saw this conversation execute it? If a step needs tribal knowledge, write the knowledge in.
- Is every acceptance criterion checkable, not aspirational?
- Are the non-goals doing real work (naming the adjacent thing the agent would plausibly wander into)?

Output to chat for pasting, or write to `tasks/brief-<slug>.md` on request.
