#!/usr/bin/env python3
"""Score /app/review.md for the subtle-migration review task.

The migration under review plants six unsafe operations and two safe ones.
Per planted issue the review earns:
  0.4  identifying the operation
  0.3  stating the concrete mechanism (lock type, rewrite, scan, deploy
       hazard) in the same finding -- keyword mentions elsewhere do not count
  0.3  stating the safe alternative in the same finding
Each safe operation flagged as a problem deducts 0.1 (over-flagging bait).

Writes the scalar reward to /logs/verifier/reward.txt and a per-issue
breakdown to /logs/verifier/score.json.
"""

import json
import pathlib
import re
import shutil

REVIEW = pathlib.Path("/app/review.md")
LOGS = pathlib.Path("/logs/verifier")

WINDOW = 300

ISSUES = [
    {
        "key": "volatile_default_reference",
        "id": r"\breference\b",
        "mechanism": r"volatile|rewrit",
        "alternative": r"without (a |the )?default|no default|backfill|separate",
    },
    {
        "key": "check_constraint_immediate_validation",
        "id": r"check_constraint|orders_total_positive|check constraint",
        "mechanism": r"scan|share ?row ?exclusive|block|validat\w* (immediately|all|every|the whole)",
        "alternative": r"validate: false|not valid|separate migration|validate_check_constraint|validate constraint",
    },
    {
        "key": "non_concurrent_index",
        "id": r"idx_orders_account_pending|add_index|index",
        "mechanism": r"blocks? writes|share lock|locks? (the )?table|write",
        "alternative": r"concurrently",
    },
    {
        "key": "foreign_key_immediate_validation",
        "id": r"foreign_key|foreign key",
        "mechanism": r"share ?row ?exclusive|scan|lock|block|validat\w* (immediately|all|every)",
        "alternative": r"validate: false|not valid|separate",
    },
    {
        "key": "rename_breaks_running_code",
        "id": r"rename|total_amount",
        "mechanism": r"old code|previous (release|version)|running code|still (serving|references|selects)|breaks|deploy",
        "alternative": r"expand[ /-]?contract|dual[ -]?write|deprecat",
    },
    {
        "key": "in_migration_backfill",
        "id": r"backfill|find_each|update_columns",
        "mechanism": r"long[ -]?running|transaction|lock|batch|throttl|90m|million",
        "alternative": r"data migration|background job|separate|batched| rake ",
    },
]

# Safe operations that must NOT be flagged as problems.
SAFE_OPS = [
    {"key": "fp_constant_default_priority", "op": r"\bpriority\b"},
    {"key": "fp_nullable_fulfillment_notes", "op": r"fulfillment_notes"},
]
UNSAFE_WORDS = r"unsafe|risky|danger|problematic|blocks? writes|must be|should be|do not ship|violation|not safe"


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

    breakdown = {}
    total = 0.0
    for issue in ISSUES:
        id_hits = list(windows(text, issue["id"]))
        identified = bool(id_hits)
        mechanism = any(
            re.search(issue["mechanism"], w, re.IGNORECASE) for w in id_hits
        )
        alternative = any(
            re.search(issue["alternative"], w, re.IGNORECASE) for w in id_hits
        )
        score = 0.4 * identified + 0.3 * mechanism + 0.3 * alternative
        breakdown[issue["key"]] = {
            "identified": identified,
            "mechanism": mechanism,
            "alternative": alternative,
            "score": round(score, 2),
        }
        total += score

    false_positives = []
    for safe in SAFE_OPS:
        for w in windows(text, safe["op"]):
            if re.search(UNSAFE_WORDS, w, re.IGNORECASE):
                false_positives.append(safe["key"])
                total -= 0.1
                break

    reward = max(0.0, min(1.0, total / len(ISSUES)))
    (LOGS / "score.json").write_text(
        json.dumps(
            {
                "reward": round(reward, 3),
                "issues": breakdown,
                "false_positives": false_positives,
            },
            indent=2,
        )
    )
    (LOGS / "reward.txt").write_text(f"{round(reward, 3)}\n")
    print(json.dumps({"reward": round(reward, 3), "false_positives": false_positives}))


if __name__ == "__main__":
    main()
