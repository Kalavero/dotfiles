#!/usr/bin/env python3
"""Score /app/review.md for the safe-migration review task (negative control).

The migrations under review are entirely safe; the correct review says so
explicitly and lists what was checked. Scoring:
  0.25          explicit "safe / no problems" verdict
  6 x 0.125     per checked dimension (0.5 for mentioning the operation,
                0.5 for the checked/confirmed-safe language in the same
                300-char window -- bare keyword mentions elsewhere do not
                count)
  -0.25 each    false positive: a window around a mention of one of the safe
                operations containing unsafe/finding-style language (the main
                discriminator against over-flagging reviews)

Writes the scalar reward to /logs/verifier/reward.txt and a breakdown to
/logs/verifier/score.json.
"""

import json
import pathlib
import re
import shutil

REVIEW = pathlib.Path("/app/review.md")
LOGS = pathlib.Path("/logs/verifier")

WINDOW = 300

VERDICT_WEIGHT = 0.25
DIMENSION_WEIGHT = 0.125
FP_PENALTY = 0.25

VERDICT = (
    r"no (production[ -]?safety )?(problems?|issues?|concerns?)( found)?"
    r"|safe to (ship|run|deploy)"
    r"|safe as written"
    r"|all operations are safe"
    r"|migration(s)? (are|is|look(s)?) safe"
)

DIMENSIONS = [
    {
        "key": "index_concurrency",
        "id": r"add_index|idx_subscriptions_account_plan|index (creation|build)",
        "checked": r"concurrently|does not block writes|non[ -]?blocking",
    },
    {
        "key": "fk_validation_timing",
        "id": r"foreign[ _]?key",
        "checked": r"validate: false|validate_foreign_key|separate migration|defer|not valid|share update exclusive",
    },
    {
        "key": "constant_column_default",
        "id": r"plan_code",
        "checked": r"constant|metadata[ -]?only|postgres 1[1-9]|pg ?1[1-9]|no table rewrite|does not rewrite",
    },
    {
        "key": "renames_type_changes_vs_running_code",
        "id": r"rename|type change|expand",
        "checked": r"none|no rename|expand[ /-]?contract|running code|previous release|old code|compatib",
    },
    {
        "key": "backfills",
        "id": r"backfill",
        "checked": r"none|no(t)? (present|data)|background job|separate data migration|batched",
    },
    {
        "key": "rollback_path",
        "id": r"rollback|\bdown\b|reversib",
        "checked": r"remove_index|remove_foreign_key|remove_column|reversib|restores|working down",
    },
]

# Safe operations that must NOT be flagged as problems.
SAFE_OPS = [
    {"key": "fp_concurrent_index", "op": r"add_index|idx_subscriptions_account_plan"},
    {"key": "fp_deferred_foreign_key", "op": r"add_foreign_key|validate: false"},
    {"key": "fp_constant_default_plan_code", "op": r"plan_code"},
    {"key": "fp_null_false", "op": r"null: false|not null"},
    {"key": "fp_nullable_column", "op": r"trial_ends_at"},
]

# Finding-style language. Negation-guarded so "does not block writes" in a
# correct review does not trip the detector.
UNSAFE_WORDS = (
    r"\bunsafe\b|\bnot safe\b|\brisky\b|\bdangerous\b|\bproblematic\b"
    r"|\bhazard\b|do not ship|must be (changed|fixed|rewritten|split|removed)"
    r"|should be (changed|fixed|split|removed)|\bviolation\b"
    r"|will (lock|block|rewrite|scan)"
    r"|(?<!not )(?<!n't )blocks? (all )?writes"
    r"|locks? the (whole |entire )?table"
    r"|rewrites? the (whole |entire )?table"
    r"|scans? the (whole |entire )?table"
)


def windows(text: str, pattern: str):
    for m in re.finditer(pattern, text, re.IGNORECASE):
        lo = max(0, m.start() - WINDOW)
        yield text[lo : m.end() + WINDOW]


def main() -> None:
    LOGS.mkdir(parents=True, exist_ok=True)
    if not REVIEW.exists():
        (LOGS / "reward.txt").write_text("0\n")
        print("MISSING /app/review.md")
        return

    text = REVIEW.read_text()
    shutil.copy(REVIEW, LOGS / "review.md")

    verdict = bool(re.search(VERDICT, text, re.IGNORECASE))
    total = VERDICT_WEIGHT * verdict

    breakdown = {}
    for dim in DIMENSIONS:
        id_hits = list(windows(text, dim["id"]))
        identified = bool(id_hits)
        checked = any(re.search(dim["checked"], w, re.IGNORECASE) for w in id_hits)
        score = DIMENSION_WEIGHT * (0.5 * identified + 0.5 * checked)
        breakdown[dim["key"]] = {
            "identified": identified,
            "checked": checked,
            "score": round(score, 3),
        }
        total += score

    false_positives = []
    for safe in SAFE_OPS:
        for w in windows(text, safe["op"]):
            if re.search(UNSAFE_WORDS, w, re.IGNORECASE):
                false_positives.append(safe["key"])
                total -= FP_PENALTY
                break

    reward = max(0.0, min(1.0, total))
    (LOGS / "score.json").write_text(
        json.dumps(
            {
                "reward": round(reward, 3),
                "verdict": verdict,
                "dimensions": breakdown,
                "false_positives": false_positives,
            },
            indent=2,
        )
    )
    (LOGS / "reward.txt").write_text(f"{round(reward, 3)}\n")
    print(json.dumps({"reward": round(reward, 3), "false_positives": false_positives}))


if __name__ == "__main__":
    main()
