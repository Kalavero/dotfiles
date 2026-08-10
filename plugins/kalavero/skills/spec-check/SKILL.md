---
name: spec-check
description: >
  Validate a built or in-review change against the success criteria in its spec. Use after
  implementation - before merge, on a PR, or after release - to check whether the thing that
  was built actually meets the criteria the idea was approved on, and to file follow-ups for
  what it missed. Use when the user asks whether the work delivered what was intended.
---

# Spec Check

Code review asks "is this correct?" This skill asks "is this what we meant to build?" It checks a finished or in-review change against the success criteria in its spec and produces a per-criterion verdict with evidence.

`$ARGUMENTS` is optional: a spec path/URL and/or a PR/branch. The default change set is the current branch.

## Phase 1 — Resolve the spec and the change set

- **Spec path** — read it with the Read tool.
- **Spec URL** — fetch it via the connected tracker/docs MCP.
- **Neither provided** — list files under `docs/specs/` and ask which one; if none exist, stop.

If there is no spec, say so and stop. Do not invent criteria — the absence of a spec is the finding; suggest running the `idea-spec` skill next time instead.

Resolve the change set the same way: the named PR or branch, or the current branch's diff against the default branch.

## Phase 2 — Extract the success criteria

Pull the success criteria out of the spec verbatim, one per row. Do not paraphrase, merge, or drop any — a criterion softened in transit is a criterion that will pass when it shouldn't.

Note any criterion the spec itself marked unmeasurable; carry that flag forward.

## Phase 3 — Gather evidence per criterion

For each criterion, find concrete evidence:

- Run the tests that demonstrate it.
- Trace the code path that implements it, with file references.
- Note a demo step or PR artifact (screenshot, CI run, log) when behavior is the evidence.

Mark a criterion **unverifiable** when only a human can judge it (a feel, a look, a workflow) — say what a human should check instead of guessing a verdict. Never mark a criterion met without evidence you actually gathered.

## Phase 4 — Verdict and follow-ups

Present the verdict table:

| Criterion | Verdict | Evidence |
|-----------|---------|----------|
| <verbatim criterion> | met / not met / unverifiable | <test, code path, demo step> |

Then:

- **Not met** criteria become a gap list: what is missing, and why the change falls short.
- Offer to post the table as a PR comment, or append it to the spec document.

For each gap, offer to file a follow-up ticket by discovering the tracker via its connected MCP, then `gh`, then stopping to ask if neither is available. **Do not create any ticket until the user explicitly approves the full list** — this is a hard requirement.

## Guidelines

- **Intent, not correctness.** The `code-reviewer` agent owns correctness — bugs, style, security. This skill owns intent — whether the delivered thing meets what the idea was approved on. Do not re-review the code.
- **Evidence or unverifiable.** There is no "probably met."
- **The criteria are the contract.** Check what the spec says, not what the change happens to do well.
