---
description: Implement a task end-to-end with the agent team — research, plan, then build/test/review each subtask
---

Orchestrate the kalavero agent team to implement `$ARGUMENTS` (a task description, a ticket ID/URL, or a path to an approved plan/TAD file).

You are the orchestrator: launch agents with the Agent tool using `subagent_type: kalavero:<name>`, relay results between them, and keep the user in the loop. Agents share no context — every prompt you send must be self-contained (the task, relevant prior results, and constraints).

### Stage 1 — Research

Launch `kalavero:researcher` with the task description (resolve a ticket to its requirements first if given an ID/URL). Share the resulting map with the user, flagging any risks or unknowns it surfaced.

### Stage 2 — Plan

Skip this stage if `$ARGUMENTS` already points to an approved plan file — read it instead.

Launch `kalavero:planner` with the task plus the full research report. Present the returned task list to the user and **wait for approval before any code is written**. Apply requested changes to the plan yourself; re-launch the planner only for structural rework.

### Stage 3 — Build loop

For each task in order (respect dependencies; never run dependent tasks in parallel):

1. **Implement**: launch `kalavero:implementer` with the complete task (goal, acceptance criteria, verification, files) plus relevant research findings and a summary of what prior tasks changed. If it reports BLOCKED, bring the question to the user — do not guess on its behalf.
2. **Build an independent review packet**: collect the original task description and acceptance criteria, the raw branch diff (including tests and untracked files), and the contents of relevant architecture docs. Look for `ARCHITECTURE.md`, `docs/architecture/`, ADR directories, and package boundary docs near the changed code; write `None found` when the repository has no relevant architecture docs. Never include the implementer's report, reasoning, implementation summary, research notes, plan rationale, prior-task summaries, conversation transcript, or Notes for review.
3. **Verify in parallel**: once DONE, launch `kalavero:test-engineer` (coverage gaps on the diff) and `kalavero:reviewer` (architecture, performance, and correctness verdict) in a single message so they run concurrently. Give the reviewer a separate self-contained prompt containing only these headings: `Task Description`, `Raw Diff`, and `Architecture Docs`. Give the test engineer the task's acceptance criteria and changed files, but do not reuse that prompt for the reviewer.
4. **Gate**:
   - Reviewer says REQUEST CHANGES, has Critical findings, or the verdict is ambiguous — treat as not approved. Send the findings (plus any Critical test gaps) back to `kalavero:implementer` as a fix task. Maximum 2 fix rounds per task; after that, escalate to the user with the unresolved findings.
   - APPROVE — commit the task's changes with a descriptive message, mark the task complete, move on.
5. Non-critical test-engineer recommendations and reviewer Suggestions: collect them in a running list instead of blocking the loop.

### Stage 4 — Checkpoints and wrap-up

- Pause for user review every 2-3 completed tasks: tasks done, commits made, anything escalated or deferred.
- At the end, summarize: all tasks with status, the commit list, the deferred-suggestions list, and verification evidence (test/build results). Offer `/kalavero:pr-create` as the next step.
