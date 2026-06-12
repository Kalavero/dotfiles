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
- **Estimate** — carry over if the TAD includes one and the tracker supports it.
- **Dependencies** — encode the TAD's sequencing section: blocking relationships where the tracker supports them, otherwise a "Depends on: ..." line in the description.

## Phase 4 — Confirm, then create

Present the complete ticket list (titles, descriptions, dependencies) for review.

**Do not create anything until the user explicitly approves the full list.** This is a hard requirement — ticket creation is outward-facing and noisy to undo.

After approval, create the tickets, then output a mapping of TAD task → ticket ID/URL. Offer to append this mapping to the TAD document.
