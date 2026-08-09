#!/usr/bin/env python3
"""Score the technical-approach document for the tad-feature-doc task.

Checks and weights (partial credit, summed to 1.0):

  doc_exists    0.05  a markdown doc exists under /app/docs/tech-approaches/
  sections      0.25  core sections present with tolerant heading matching:
                      goal, assumptions, approach, scope (with explicit in/out),
                      proposed tasks, test plan, rollout — equal share each
  groundedness  0.40  fraction of cited repo paths that actually exist under
                      /app (see heuristic below); the main discriminator
  feature_flag  0.15  a flag name appears in Assumptions (0.075) AND a
                      flag-removal step appears in Rollout (0.075)
  tasks         0.10  proposed-tasks section has >= 3 tasks (0.05) and a
                      sequencing note (0.05)
  no_emojis     0.05  no emoji anywhere in the doc

Groundedness heuristic:
  - Extract backticked spans from the doc. A span is a path candidate when it
    has no whitespace, no URL scheme, no glob/placeholder characters
    (*, <, >, {, }, $) and ends in a known file extension.
  - A candidate is EXEMPT (counted as proposed-new, not scored) when the line
    citing it, or the heading of the section containing that line, matches
    new/create/add/proposed/introduce — this is how the doc marks files that
    do not exist yet. A path cited in both an exempt and a non-exempt context
    is treated as non-exempt (strict).
  - Every remaining candidate must exist under /app (a leading "/app/" or
    "./" is stripped first). Each missing one is a fabrication.
  - A doc that cites no paths at all scores 0 on groundedness.

Writes the scalar reward to /logs/verifier/reward.txt and a per-check
breakdown to /logs/verifier/score.json.
"""

import json
import pathlib
import re
import shutil

APP = pathlib.Path("/app")
DOC_DIR = APP / "docs" / "tech-approaches"
LOGS = pathlib.Path("/logs/verifier")

WEIGHTS = {
    "doc_exists": 0.05,
    "sections": 0.25,
    "groundedness": 0.40,
    "feature_flag": 0.15,
    "tasks": 0.10,
    "no_emojis": 0.05,
}

HEADING_RE = re.compile(r"(?m)^(#{1,6})\s+(.*?)\s*$")
BACKTICK_RE = re.compile(r"`([^`\n]+)`")
EXT_RE = re.compile(
    r"\.(py|md|txt|json|ya?ml|toml|cfg|ini|sh|sql|csv|lock|rb|js|ts)$", re.I
)
NEW_WORDS_RE = re.compile(r"\b(new|creat\w+|add\w*|propos\w*|introduc\w+)\b", re.I)
EMOJI_RE = re.compile(
    "[\U0001F000-\U0001FAFF\U0001F1E6-\U0001F1FF"
    "\u2600-\u27BF\u2B00-\u2BFF\uFE0F]"
)

SECTION_PATTERNS = {
    "goal": r"\bgoal\b|\bobjective\b",
    "assumptions": r"assumption",
    "approach": r"\bapproach\b|\bdesign\b|\bsolution\b",
    "scope": r"\bscope\b",
    "proposed_tasks": r"\btasks?\b|work breakdown|implementation plan",
    "test_plan": r"test(ing)? (plan|strategy)|\btesting\b",
    "rollout": r"roll[ -]?out|release plan|deployment plan",
}

FLAG_NAME_RE = re.compile(r"`[a-z0-9][a-z0-9_.\-]*`|\b[a-z][a-z0-9]*(_[a-z0-9]+)+\b")
FLAG_REMOVAL_RE = re.compile(r"remov|retire|clean[ -]?up|drop|delet|sunset", re.I)


def split_sections(text):
    """Return [(heading_lower, body)] for every markdown heading.

    A section's body spans until the next heading of the same or higher
    level, so subsections (e.g. numbered task headings under "Proposed
    tasks") belong to their parent section.
    """
    matches = list(HEADING_RE.finditer(text))
    out = []
    for i, m in enumerate(matches):
        level = len(m.group(1))
        end = len(text)
        for nxt in matches[i + 1:]:
            if len(nxt.group(1)) <= level:
                end = nxt.start()
                break
        out.append((m.group(2).strip().lower(), text[m.end():end]))
    return out


def find_body(sections, pattern):
    for head, body in sections:
        if re.search(pattern, head, re.I):
            return body
    return None


def scope_has_in_out(body):
    has_in = re.search(r"(?im)^\s*in\s*:|\bin[ -]scope\b|\bin scope\b", body)
    has_out = re.search(
        r"(?im)^\s*out\s*:|\bout[ -]of[ -]scope\b|\bout of scope\b", body
    )
    return bool(has_in and has_out)


def count_tasks(body):
    heads = len(re.findall(r"(?m)^#{2,6}\s*\d+\b", body))
    items = len(re.findall(r"(?m)^\s*\d+[.)]\s+\S", body))
    return max(heads, items)


def normalize_path(span):
    """Return a repo-relative path candidate, or None if the span is not one."""
    s = span.strip()
    if not s or re.search(r"\s", s):
        return None
    if "://" in s:
        return None
    if any(c in s for c in "*<>{}$"):
        return None
    if not EXT_RE.search(s):
        return None
    if s.startswith("/app/"):
        s = s[len("/app/"):]
    while s.startswith("./"):
        s = s[2:]
    return s or None


def groundedness(text):
    """Score cited-path groundedness. Returns (score, detail dict)."""
    # path -> list of exempt flags, one per citation
    citations = {}
    heading = ""
    for line in text.splitlines():
        m = re.match(r"^#{1,6}\s+(.*?)\s*$", line)
        if m:
            heading = m.group(1)
        for span in BACKTICK_RE.findall(line):
            path = normalize_path(span)
            if path is None:
                continue
            exempt = bool(NEW_WORDS_RE.search(line) or NEW_WORDS_RE.search(heading))
            citations.setdefault(path, []).append(exempt)

    grounded, fabricated, proposed_new = [], [], []
    for path, exempts in sorted(citations.items()):
        if exempts and all(exempts):
            proposed_new.append(path)
        elif (APP / path).exists():
            grounded.append(path)
        else:
            fabricated.append(path)

    total = len(grounded) + len(fabricated)
    score = len(grounded) / total if total else 0.0
    return score, {
        "grounded": grounded,
        "fabricated": fabricated,
        "proposed_new": proposed_new,
    }


def find_doc():
    if not DOC_DIR.is_dir():
        return None
    docs = sorted(DOC_DIR.glob("*.md"))
    if not docs:
        return None
    # Deterministic pick when several docs exist: the largest one.
    return max(docs, key=lambda p: p.stat().st_size)


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    doc_path = find_doc()
    if doc_path is None:
        (LOGS / "reward.txt").write_text("0\n")
        (LOGS / "score.json").write_text(
            json.dumps({"reward": 0, "error": "no markdown doc under /app/docs/tech-approaches/"})
        )
        print("MISSING /app/docs/tech-approaches/*.md")
        return

    text = doc_path.read_text()
    shutil.copy(doc_path, LOGS / "submission.md")
    sections = split_sections(text)

    breakdown = {}
    total = 0.0

    # (a) doc exists
    breakdown["doc_exists"] = {"score": WEIGHTS["doc_exists"], "doc": doc_path.name}
    total += WEIGHTS["doc_exists"]

    # (b) core sections, equal share of the sections weight
    per_section = WEIGHTS["sections"] / len(SECTION_PATTERNS)
    section_detail = {}
    for key, pattern in SECTION_PATTERNS.items():
        body = find_body(sections, pattern)
        present = body is not None
        if key == "scope" and present:
            present = scope_has_in_out(body)
        section_detail[key] = present
        if present:
            total += per_section
    breakdown["sections"] = {
        "score": round(per_section * sum(section_detail.values()), 3),
        "present": section_detail,
    }

    # (c) groundedness
    g_score, g_detail = groundedness(text)
    breakdown["groundedness"] = {"score": round(g_score * WEIGHTS["groundedness"], 3), **g_detail}
    total += g_score * WEIGHTS["groundedness"]

    # (d) feature flag: named in Assumptions + removal step in Rollout
    assum_body = find_body(sections, SECTION_PATTERNS["assumptions"]) or ""
    rollout_body = find_body(sections, SECTION_PATTERNS["rollout"]) or ""
    flag_named = bool(re.search(r"flag", assum_body, re.I)) and bool(
        FLAG_NAME_RE.search(assum_body)
    )
    flag_removed = bool(re.search(r"flag", rollout_body, re.I)) and bool(
        FLAG_REMOVAL_RE.search(rollout_body)
    )
    half = WEIGHTS["feature_flag"] / 2
    breakdown["feature_flag"] = {
        "score": round(half * flag_named + half * flag_removed, 3),
        "named_in_assumptions": flag_named,
        "removal_in_rollout": flag_removed,
    }
    total += half * flag_named + half * flag_removed

    # (f) >= 3 proposed tasks + sequencing note
    tasks_body = find_body(sections, SECTION_PATTERNS["proposed_tasks"]) or ""
    n_tasks = count_tasks(tasks_body)
    has_sequencing = bool(re.search(r"sequenc|parallel|depend", tasks_body, re.I))
    half = WEIGHTS["tasks"] / 2
    breakdown["tasks"] = {
        "score": round(half * (n_tasks >= 3) + half * has_sequencing, 3),
        "task_count": n_tasks,
        "sequencing_note": has_sequencing,
    }
    total += half * (n_tasks >= 3) + half * has_sequencing

    # (e) no emojis
    emojis = EMOJI_RE.findall(text)
    breakdown["no_emojis"] = {"score": WEIGHTS["no_emojis"] if not emojis else 0.0}
    if not emojis:
        total += WEIGHTS["no_emojis"]

    reward = round(max(0.0, min(1.0, total)), 3)
    (LOGS / "score.json").write_text(
        json.dumps({"reward": reward, "checks": breakdown}, indent=2)
    )
    (LOGS / "reward.txt").write_text(f"{reward}\n")
    print(json.dumps({"reward": reward, "checks": breakdown}, indent=2))


if __name__ == "__main__":
    main()
