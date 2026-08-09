---
name: tad-to-tickets
description: >
  Convert an approved technical approach document (TAD) into tracker tickets. Use when a TAD or
  tech approach is approved and its proposed tasks need to become tickets in the issue tracker.
  Use when the user asks to create tickets, issues, or stories from a design doc or tech approach.
---

# TAD to Tickets

Turn the "Proposed tasks" section of a TAD into well-formed tracker tickets, preserving sequencing and dependencies.

`$ARGUMENTS` is optional: a path to a TAD file (typically `docs/tech-approaches/*.md`) or a document URL.

## Phase 1 — Load the TAD

- **File path** — read it with the Read tool.
- **Document URL** — fetch it via the connected tracker/docs MCP.
- **Neither provided** — list files under `docs/tech-approaches/` and ask which one; if none exist, ask for the source.

Confirm the document has a proposed-tasks section (or equivalent). If the TAD is a draft or has unresolved open questions that affect task scope, surface them before continuing.

## Phase 2 — Discover the tracker

- Use the connected tracker MCP if one exists (Linear, Jira, or similar).
- Else fall back to GitHub Issues via `gh`.
- Else stop and ask the user where tickets should go.

Ask the user which project/team/milestone the tickets belong to if the tracker requires one and it isn't obvious.

## Phase 3 — Draft the tickets

Map each proposed task to a ticket:

- **Title** — the task title, prefixed or labeled per the tracker's visible conventions (check a few recent tickets).
- **Description** — the task's body from the TAD, plus a link back to the TAD document. Each ticket must be self-contained: an engineer picking it up should not need the conversation, only the ticket and the TAD link.
- **Estimate** — assign a relative point estimate using the scale below. Carry over the TAD's estimate if it has one; otherwise derive it. Map the points onto the tracker's own estimate field when it has one.
- **Dependencies** — encode the TAD's sequencing section: blocking relationships where the tracker supports them, otherwise a "Depends on: ..." line in the description.
- **Phase** — mark whether the task belongs to the MVP cut or later work (from the TAD's sequencing, or the spec's MVP cut when one exists), via the tracker's label/milestone field or a "Phase: MVP" line in the description.

### Estimation scale

Size each task on a relative-points scale that blends three things: time to deliver, complexity, and uncertainty (unknowns you'll only hit mid-work). Points are not hours — the delivery times below just anchor the scale.

| Points | Delivery time | Complexity & certainty | Examples |
|--------|---------------|------------------------|----------|
| 0 | Minutes; many in a day | None — you know exactly what to do | CSS color change, fix a typo, flip an env var, run a data task |
| 1 | ~An hour; several in a day | Minimal — you know exactly what to do | Add a form field, simple migration, fix a query with a spec, add a basic test |
| 2 | Hours / half-day; ~one a day | Some — you mostly know what and where | Build a modal with form validation |
| 3 | A day to a day and a half | Moderate, with some unknowns | New endpoint with validation and tests; a multi-step form |
| 5 | 2–3 days | High complexity; unknowns likely surface during the work | Feature spanning several layers, introducing a new pattern |
| 8 | ~A week | High complexity; critical unknowns | Too big — split before it becomes a ticket |

Rules:
- An 8 must be broken into smaller tasks before it becomes a ticket — flag it, don't create it as-is. A 5 is large; split it when you reasonably can.
- When torn between two values, take the higher one and note the uncertainty in the ticket.

## Phase 4 — Confirm, then create

Present the complete ticket list (titles, descriptions, estimates, dependencies) for review.

**Do not create anything until the user explicitly approves the full list.** This is a hard requirement — ticket creation is outward-facing and noisy to undo.

After approval, create the tickets, then output a mapping of TAD task → ticket ID/URL. Offer to append this mapping to the TAD document.
