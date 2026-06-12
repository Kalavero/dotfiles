---
name: refactor-plan
description: >
  Produce a safe refactoring plan that improves code structure without changing behavior. Use
  before any non-trivial refactor — extracting modules, restructuring classes, replacing a
  pattern — when accidentally changing behavior is the main risk.
---

# Refactor Plan

A refactor changes structure while preserving behavior. This skill produces a plan where behavior preservation is verified at every step, not asserted at the end.

This complements the code-simplification skill: that one covers *what* to simplify; this one covers *how* to do it without breaking anything.

## Phase 1 — Behavior inventory

Before planning any change:

- Map what the code currently does, including quirks and edge cases. Quirks are behavior too — something may depend on them.
- Assess test coverage of the target: run the project's coverage tooling if available, otherwise read the specs and list which behaviors are pinned and which are not.
- **Where coverage is thin, write characterization tests first** — tests that pin current behavior exactly as it is, including behavior that looks wrong. (Fixing a bug is a separate change with its own commit, before or after the refactor, never during.)

Do not proceed until the behaviors at risk are pinned by tests.

## Phase 2 — Define the contract

Write the explicit list of observable behaviors that must not change:

- Outputs and return values, including error shapes and edge-case results
- Side effects: writes, events, jobs enqueued, logs that anything depends on
- Public API surface: signatures, routes, serialized formats
- Performance characteristics, when callers depend on them

This contract is the refactor's definition of done.

## Phase 3 — Sequence the steps

Break the refactor into small, independently committable steps:

- The full test suite is green after every step — no step leaves the code in a broken intermediate state.
- Identify the seams that make this possible (delegation shims, parallel implementations, adapter layers); plan their introduction and their removal.
- Put the riskiest transformation as early as possible, while context is fresh and the diff is small.
- Each step reversible with a single revert.

Discipline rules for execution:

- No functional changes mixed in — improvements spotted along the way are noted, not done.
- No API changes unless explicitly in scope.
- Mechanical steps (renames, moves) and judgment steps (restructuring) in separate commits, so reviewers can skim the former and scrutinize the latter.

## Phase 4 — Verification per step and overall

- Per step: run the suite; review the diff specifically for behavior-affecting changes hiding in "just structure".
- At the end: walk the Phase 2 contract item by item and state how each was verified.

Output the plan to chat, or to `tasks/refactor-<slug>.md` on request. Execute with the incremental-implementation skill, one step at a time.
