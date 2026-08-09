#!/usr/bin/env python3
"""Score /app/tasks/brief-*.md for the agent-brief rough-idea task.

Checks (weights):
  sections       0.30  all six brief sections present as headings (objective,
                       context, constraints, acceptance criteria, non-goals,
                       verification) — tolerant heading matching
  criteria       0.20  3–7 checkable acceptance criteria items (checkbox or
                       bullet list under the criteria section); 2 or 8 earns
                       half credit
  groundedness   0.25  every backticked repo-relative path cited as existing
                       actually exists under /app (lines proposing something
                       new — containing new/create/add — are exempt)
  non_goals      0.10  non-goals section has >= 1 substantive bullet
  verification   0.15  verification section names the repo's real test
                       command (pytest)

Writes the scalar reward to /logs/verifier/reward.txt and a per-check
breakdown to /logs/verifier/score.json.
"""

import json
import pathlib
import re
import shutil

APP = pathlib.Path("/app")
TASKS = APP / "tasks"
LOGS = pathlib.Path("/logs/verifier")

SECTIONS = {
    "objective": r"objective|goal",
    "context": r"context|background",
    "constraints": r"constraint|requirement|must[- ]not",
    "acceptance_criteria": r"acceptance|success criteri|definition of done|done when",
    "non_goals": r"non[- ]?goal|out of scope|exclusion",
    "verification": r"verif|how to (test|verify)|testing|checks?\b",
}

PATHISH = re.compile(r"^[\w.~@-]+(?:/[\w.~@-]+)+$|^[\w-]+\.(?:py|md|toml|txt|cfg|csv|json|ya?ml|sh|rb)$")
NEW_LINE = re.compile(r"\b(new|creat\w+|add\w*|propos\w+)\b", re.I)
BACKTICK = re.compile(r"`([^`]+)`")


def split_sections(text):
    """Return list of (heading, body) for each markdown heading."""
    sections = []
    current_head, current_body = None, []
    for line in text.splitlines():
        m = re.match(r"^#{1,6}\s+(.+?)\s*$", line)
        if m:
            if current_head is not None:
                sections.append((current_head, "\n".join(current_body)))
            current_head, current_body = m.group(1), []
        else:
            current_body.append(line)
    if current_head is not None:
        sections.append((current_head, "\n".join(current_body)))
    return sections


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    briefs = sorted(TASKS.glob("brief-*.md")) if TASKS.is_dir() else []

    if not briefs:
        (LOGS / "score.json").write_text(
            json.dumps({"reward": 0.0, "fatal": "no /app/tasks/brief-*.md"}, indent=2)
        )
        (LOGS / "reward.txt").write_text("0\n")
        print(json.dumps({"reward": 0.0, "fatal": "no brief file"}))
        return

    brief = briefs[0]
    text = brief.read_text()
    shutil.copy(brief, LOGS / brief.name)
    sections = split_sections(text)
    breakdown = {"brief": str(brief), "briefs_found": [str(b) for b in briefs]}

    def section_body(key):
        pat = re.compile(SECTIONS[key], re.I)
        bodies = [body for head, body in sections if pat.search(head)]
        return "\n".join(bodies) if bodies else None

    # (a)+(b) sections present.
    found = {key: section_body(key) is not None for key in SECTIONS}
    sections_score = sum(found.values()) / len(SECTIONS)

    # (c) acceptance criteria count: bullets (checkbox or plain) in that section.
    ac_body = section_body("acceptance_criteria") or ""
    items = [
        ln for ln in ac_body.splitlines()
        if re.match(r"^\s*[-*]\s+(\[[ xX]\]\s+)?\S", ln)
    ]
    n = len(items)
    if 3 <= n <= 7:
        criteria_score = 1.0
    elif n in (2, 8):
        criteria_score = 0.5
    else:
        criteria_score = 0.0

    # (d) groundedness: backticked path citations must exist under /app.
    checked, missing = [], []
    for line in text.splitlines():
        for span in BACKTICK.findall(line):
            span = span.strip()
            if " " in span or any(c in span for c in "*<>$"):
                continue
            if span.startswith("/"):
                if not span.startswith("/app/"):
                    continue  # outside-repo absolute paths are not graded
                target = pathlib.Path(span)
            elif PATHISH.match(span):
                target = APP / span
            else:
                continue
            if NEW_LINE.search(line):
                continue  # proposed-new file, exempt
            checked.append(span)
            if not target.exists():
                missing.append(span)
    groundedness = (
        (len(checked) - len(missing)) / len(checked) if checked else 0.0
    )

    # (e) non-goals: at least one substantive bullet.
    ng_body = section_body("non_goals") or ""
    ng_bullets = [
        ln for ln in ng_body.splitlines() if re.match(r"^\s*[-*]\s+", ln)
    ]
    substantive = [ln for ln in ng_bullets if len(ln.strip()) >= 40]
    non_goals_score = 1.0 if substantive else 0.0

    # (f) verification names the repo's real test command.
    ver_body = section_body("verification") or ""
    verification_score = 1.0 if re.search(r"pytest", ver_body, re.I) else 0.0

    reward = (
        0.30 * sections_score
        + 0.20 * criteria_score
        + 0.25 * groundedness
        + 0.10 * non_goals_score
        + 0.15 * verification_score
    )
    reward = max(0.0, min(1.0, reward))

    breakdown.update(
        {
            "reward": round(reward, 3),
            "sections": {"score": round(sections_score, 3), "found": found},
            "acceptance_criteria": {
                "score": criteria_score,
                "count": n,
            },
            "groundedness": {
                "score": round(groundedness, 3),
                "paths_checked": checked,
                "paths_missing": missing,
            },
            "non_goals": {
                "score": non_goals_score,
                "bullets": len(ng_bullets),
                "substantive": len(substantive),
            },
            "verification": {"score": verification_score},
        }
    )
    (LOGS / "score.json").write_text(json.dumps(breakdown, indent=2))
    (LOGS / "reward.txt").write_text(f"{round(reward, 3)}\n")
    print(json.dumps({"reward": round(reward, 3)}))


if __name__ == "__main__":
    main()
