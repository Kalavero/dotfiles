---
name: idea-spec
description: >
  Shape a raw idea into a validated spec with success criteria. Use when an idea is still
  unformed - no ticket, no PRD, no clear problem statement - and needs problem-space
  exploration, a build/defer/drop call, and a definition of "useful" before any design or
  delegation. Use when the user asks to think through, validate, or write up an idea.
---

# Idea to Spec

A raw idea enters the pipeline as a sentence, not a task. This skill explores the problem space, decides whether the idea is worth building, and writes a spec with measurable success criteria that downstream pieces (`tad`, `agent-brief`, `plan`, `spec-check`) can consume.

`$ARGUMENTS` is optional context: the raw idea in any form — a sentence, notes, a link. No repo, ticket, or prior artifact required.

## Phase 0 — Choose output destination

Before gathering any context, ask the user:

> "Where should the spec live? Reply with:
>
> - **`markdown`** — I'll write a new file under `docs/specs/<slug>.md`.
> - **`document`** — paste the URL of an existing document in your connected tracker or docs tool and I'll update it. I won't create one from scratch."

Wait for an answer before proceeding. For **document**, resolve the URL and confirm the document exists using the connected MCP's document-fetch tool before continuing.

Carry this decision through to Phase 4.

## Phase 1 — Idea intake interview

Ask only what the idea leaves genuinely open (usually 2-4 questions):

- What happened that made you want this?
- Who else has this problem? How do you know?
- What do people do about it today?
- What would "this was worth building" look like, in terms you could check?

Skip questions that research can answer — go look instead.

## Phase 2 — Problem-space research

Before writing anything:

- If the idea targets an existing product or repo, search it for what exists today (the feature's neighbors, prior attempts, related config).
- Name existing solutions — competitors, libraries, internal tools. Prefer reuse over rebuild.
- Check whether the problem is already solved well enough.

Never fabricate usage data, users, or file paths. Only reference what you actually found. If you don't know who has the problem, that absence is a finding — record it, don't invent demand.

## Phase 3 — The worth-building call

Make the call and state it as a verdict with reasons:

- **pursue** — the problem is real, existing solutions fall short, and the criteria below are reachable.
- **defer** — worth doing, not now; record what would change the answer.
- **drop** — already solved, not a real problem, or the cost clearly outweighs the benefit.

Defer and drop are successful outcomes — the spec captures the reasoning so the idea never has to be re-litigated from scratch. Present the verdict to the user before drafting; the final call is theirs.

## Phase 4 — Write the spec

Use the destination chosen in Phase 0. For **markdown**, write to `docs/specs/<slug>.md` where `<slug>` is a kebab-case name derived from the idea. Iterate with the user — the conversation IS the design process.

```markdown
# <Idea title> — Spec

## Problem
<Who hurts, how, and how we know. Evidence, not vibes.>

## Alternatives considered
<Existing solutions, build/buy/defer options, and why each falls short or wins.>

## Verdict
<pursue / defer / drop, with the reason.>

## Success criteria
<Measurable conditions — each one checkable after the thing is built. Mark any criterion that cannot be measured as explicitly unmeasurable, and say why it still belongs.>

## MVP cut
<The smallest thing that could meet the success criteria.>

## Non-goals
<Explicitly out of scope, to prevent over-reach.>

## Open questions
<Only genuinely unresolved items.>
```

## Phase 5 — Route

Close by naming the next piece, with the spec path as its input:

- **Design-heavy or multi-system** — run the `tad` skill with the spec as its reference document; the spec is the PRD anchor `tad` asks for.
- **Small and well-understood** — the `agent-brief` skill for delegation, or straight to `/kalavero:start-ticket` / `/kalavero:plan`; the spec is the "SPEC.md or equivalent" `plan` assumes.
- **Verdict defer/drop** — stop. The spec records why; do not file tickets for ideas that were not approved.

## Guidelines

- **Measurable or marked.** Every success criterion is checkable, or explicitly flagged unmeasurable with a reason. Aspirational criteria break `spec-check` downstream.
- **The verdict is the point.** A spec without a pursue/defer/drop call is unfinished.
- **No fabricated demand.** If the evidence for the problem is one person's annoyance, say that.
- **Keep it short.** A spec someone won't read protects nothing.
