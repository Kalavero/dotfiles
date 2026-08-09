#!/usr/bin/env python3
"""Score /app/refactor-pricing.md for the tangled-module refactoring-plan task.

The plan earns:
  0.30  a behavior-pinning ("characterization") test step ordered before any
        restructuring step (full credit only when it is the first step)
  0.35  an explicit behavior-contract section with >= 4 items that names the
        two quirks, whose signature values are derived here by RUNNING the
        module, plus the coupon/tax relationship and the public API surface
        (0.10 section exists, 0.05 per sub-check)
  0.15  every step claims per-step verification (suite green / pytest)
  0.20  mechanical steps (moves/renames) exist separately from judgment
        steps (restructuring), with no step mixing both
  -0.15 penalty if a step schedules fixing/changing a quirk's behavior

Writes the scalar reward to /logs/verifier/reward.txt and a breakdown to
/logs/verifier/score.json.
"""

import json
import pathlib
import re
import shutil
import subprocess
import sys

PLAN = pathlib.Path("/app/refactor-pricing.md")
LOGS = pathlib.Path("/logs/verifier")

# A "step section" heading: mentions steps/phases/sequence/roadmap anywhere,
# or is exactly a plan heading ("## Plan", "## Refactoring plan"). The exact-
# match alternative deliberately excludes document titles like
# "# Safe refactor plan for pricing.py".
STEP_SECTION_RE = re.compile(
    r"^(?:#{1,4}\s+.*\b(?:steps?|phases?|sequence|roadmap)\b.*|"
    r"#{1,4}\s+(?:the\s+)?(?:\w+\s+)?plan\s*:?\s*)$",
    re.IGNORECASE | re.MULTILINE,
)

# Heading-style and bold-led step starters; recognized anywhere.
STEP_HEAD_RE = re.compile(
    r"^(?:#{1,4}\s*step\s+(\d+)\b|#{1,4}\s+(\d+)[.:)]\s|"
    r"\*\*\s*step\s+(\d+)\b|\*\*\s*(\d+)[.)]\s*\*\*)",
    re.IGNORECASE | re.MULTILINE,
)

# Plain top-level numbered list items ("1. Add tests ..."). Recognized only
# inside a step section, so numbered lists elsewhere (contract items, "suggested
# order" recaps) are not mistaken for steps.
NUMBERED_ITEM_RE = re.compile(r"^(\d+)[.)]\s+\S", re.MULTILINE)

CHAR_RE = re.compile(
    r"characteri|pin(s|ned|ning)?\b.{0,60}(behavi|as[ -]is|exactly)|"
    r"(current|existing) behavi|safety net|golden master|"
    r"tests?.{0,80}(pin|current behavi|existing behavi)",
    re.IGNORECASE,
)
TEST_WORD = re.compile(r"\btest", re.IGNORECASE)
RESTRUCT_RE = re.compile(
    r"extract|split|restructur|decouple|decompose|introduce\s+\w*\s*(new\s+)?module|"
    r"separate\b.{0,40}\binto",
    re.IGNORECASE,
)
MECH_RE = re.compile(r"\brename|\bmove|\bmoved|\bmoving|\bmechanical", re.IGNORECASE)
VERIFY_RE = re.compile(
    r"pytest|suite.{0,30}green|green.{0,30}suite|tests?\s+(pass|stay|remain)|"
    r"full\s+(test\s+)?suite",
    re.IGNORECASE,
)
QUIRK_WORDS = re.compile(r"round|coupon|tax", re.IGNORECASE)
FIX_WORDS = re.compile(r"\bfix|\bfixing|\bcorrect|\bcorrecting|\brepair|\badjust", re.IGNORECASE)
CHANGE_QUIRK_RE = re.compile(
    r"(fix|correct|repair)\w*\s+(the\s+)?(rounding|coupon|tax|2\.67|76\.8)|"
    r"(rounding|coupon)\s+\w{0,20}(fix|correct|repair|bug)",
    re.IGNORECASE,
)


def derive_quirk_tokens():
    """Run the module to derive the quirk signature strings."""
    code = (
        "import json, pricing\n"
        "pricing.set_region('CA')\n"
        "d = pricing.price_order([('widget', 5.35, 1)], promo='HALFOFF')['discount']\n"
        "t = pricing.price_order([('gadget', 80.0, 1)], coupon='TENOFF')['total']\n"
        "print(json.dumps({'discount': d, 'total': t}))\n"
    )
    out = subprocess.run(
        [sys.executable, "-c", code], cwd="/app", capture_output=True, text=True
    )
    data = json.loads(out.stdout)
    return str(data["discount"]), str(data["total"])


def _section_span(text, heading_match):
    """Return (start, end) of the body under a heading, up to the next
    heading of the same or higher level."""
    level = len(re.match(r"^#+", text[heading_match.start() :]).group(0))
    rest = text[heading_match.end() :]
    nxt = re.search(rf"^#{{1,{level}}}\s", rest, re.MULTILINE)
    end = heading_match.end() + nxt.start() if nxt else len(text)
    return heading_match.end(), end


def parse_steps(text):
    """Return list of (number, block_text) in document order.

    Heading/bold-led step starters are recognized anywhere in the document.
    Plain numbered list items are recognized only inside a step/plan-like
    section, so recap lists elsewhere do not count as steps.
    """
    section = STEP_SECTION_RE.search(text)
    if section:
        start, end = _section_span(text, section)
        scope = text[start:end]
        patterns = (STEP_HEAD_RE, NUMBERED_ITEM_RE)
    else:
        scope = text
        patterns = (STEP_HEAD_RE,)
    matches = sorted(
        (m for pat in patterns for m in pat.finditer(scope)),
        key=lambda m: m.start(),
    )
    steps = []
    for i, m in enumerate(matches):
        num = int(next(g for g in m.groups() if g))
        end = matches[i + 1].start() if i + 1 < len(matches) else len(scope)
        steps.append((num, scope[m.start() : end]))
    return steps


CONTRACT_HEADING_RE = re.compile(
    r"^#{1,4}\s+.*(?:contract|observed\s+behavior|current\s+behavior|"
    r"behavior[s]?\s+to\s+(?:preserve|pin|keep|not\s+change)|"
    r"behavior[s]?\s+(?:that\s+)?must\s+not\s+change|invariants?).*$",
    re.IGNORECASE | re.MULTILINE,
)


def contract_sections(text):
    """Bodies of all behavior-contract-like sections (equivalent headings
    such as "behavior contract", "observed behavior to preserve", "current
    behavior" are all accepted)."""
    return [
        text[start:end]
        for m in CONTRACT_HEADING_RE.finditer(text)
        for start, end in [_section_span(text, m)]
    ]


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    if not PLAN.exists():
        (LOGS / "reward.txt").write_text("0\n")
        (LOGS / "score.json").write_text(json.dumps({"reward": 0, "error": "missing plan"}))
        print("MISSING /app/refactor-pricing.md")
        return

    text = PLAN.read_text()
    shutil.copy(PLAN, LOGS / "refactor-pricing.md")

    discount_token, total_token = derive_quirk_tokens()
    steps = parse_steps(text)
    breakdown = {"quirk_tokens": [discount_token, total_token], "n_steps": len(steps)}

    # (b) characterization-tests step before any restructuring step ---------
    char_idx = next(
        (i for i, (_, b) in enumerate(steps) if TEST_WORD.search(b) and CHAR_RE.search(b)),
        None,
    )
    rest_idx = next(
        (i for i, (_, b) in enumerate(steps) if RESTRUCT_RE.search(b)), None
    )
    if char_idx == 0 and (rest_idx is None or rest_idx > 0):
        ordering = 0.30
    elif char_idx is not None and (rest_idx is None or char_idx < rest_idx):
        ordering = 0.18
    else:
        ordering = 0.0
    breakdown["ordering"] = {
        "characterization_step_index": char_idx,
        "first_restructuring_step_index": rest_idx,
        "score": ordering,
    }

    # (c) behavior contract section -----------------------------------------
    # Accept equivalent headings; score the best-matching candidate section.
    contract = {
        "section_exists": 0.0,
        "enough_items": 0.0,
        "rounding_quirk_token": 0.0,
        "coupon_quirk_token": 0.0,
        "coupon_tax_described": 0.0,
        "api_surface_listed": 0.0,
    }
    for section in contract_sections(text):
        items = [
            ln
            for ln in section.splitlines()
            if re.match(r"^\s*(?:[-*+]|\d+[.:)])\s", ln)
        ]
        candidate = {
            "section_exists": 0.10,
            "enough_items": 0.05 if len(items) >= 4 else 0.0,
            "rounding_quirk_token": 0.05 if discount_token in section else 0.0,
            "coupon_quirk_token": 0.05 if total_token in section else 0.0,
            "coupon_tax_described": 0.05
            if re.search(r"coupon", section, re.I) and re.search(r"tax", section, re.I)
            else 0.0,
            "api_surface_listed": 0.05
            if re.search(r"public api|api surface|signature", section, re.I)
            else 0.0,
        }
        if sum(candidate.values()) > sum(contract.values()):
            contract = candidate
    breakdown["contract"] = {"score": sum(contract.values()), **contract}

    # (d) per-step verification ---------------------------------------------
    if steps:
        green = sum(1 for _, b in steps if VERIFY_RE.search(b))
        per_step = 0.15 * green / len(steps)
    else:
        per_step = 0.0
    breakdown["per_step_green"] = {"score": round(per_step, 4)}

    # (e) mechanical vs judgment separation ----------------------------------
    mech_only = sum(
        1 for _, b in steps if MECH_RE.search(b) and not RESTRUCT_RE.search(b)
    )
    rest_only = sum(
        1 for _, b in steps if RESTRUCT_RE.search(b) and not MECH_RE.search(b)
    )
    mixed = sum(1 for _, b in steps if MECH_RE.search(b) and RESTRUCT_RE.search(b))
    separation = 0.10 * (mech_only > 0) + 0.10 * (rest_only > 0)
    if mixed:
        separation /= 2
    breakdown["mech_vs_judgment"] = {
        "mechanical_only_steps": mech_only,
        "judgment_only_steps": rest_only,
        "mixed_steps": mixed,
        "score": round(separation, 4),
    }

    # (f) quirk must not be scheduled for fixing -----------------------------
    # Per-step check is line-scoped (a fix word and a quirk reference on the
    # same line), and explicit "do not fix" preservation statements are not
    # penalized.
    quirk_fix = bool(CHANGE_QUIRK_RE.search(text))
    if not quirk_fix:
        for _, b in steps:
            for line in b.splitlines():
                if re.search(
                    r"\b(?:not|never|without)\s+\w{0,12}(fix|correct|repair|adjust)",
                    line,
                    re.IGNORECASE,
                ):
                    continue
                if FIX_WORDS.search(line) and (
                    QUIRK_WORDS.search(line)
                    or discount_token in line
                    or total_token in line
                ):
                    quirk_fix = True
                    break
            if quirk_fix:
                break
    penalty = 0.15 if quirk_fix else 0.0
    breakdown["quirk_fix_penalty"] = {"triggered": quirk_fix, "score": -penalty}

    total = ordering + sum(contract.values()) + per_step + separation - penalty
    reward = max(0.0, min(1.0, total))
    breakdown["reward"] = round(reward, 3)

    (LOGS / "score.json").write_text(json.dumps(breakdown, indent=2))
    (LOGS / "reward.txt").write_text(f"{round(reward, 3)}\n")
    print(json.dumps({"reward": round(reward, 3)}))


if __name__ == "__main__":
    main()
