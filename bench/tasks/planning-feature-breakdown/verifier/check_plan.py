#!/usr/bin/env python3
"""Structural verifier for /app/PLAN.md (planning-feature-breakdown).

The agent's output is a markdown plan; this checker is a tolerant parser
(headings, bold labels, or list items all count) that is strict about the
required elements. Checks and weights (each documented at its site):

  a. task_count    0.10  >= 4 distinct tasks (scaled below that)
  b. acceptance    0.15  every task has an acceptance-criteria section
  c. verification  0.15  every task has verification steps
  d. dependencies  0.10  every task declares dependencies ("None" counts)
  e. files_budget  0.20  every task lists the files it touches and no task
                         lists more than 5 (XL-task rejection — key
                         discriminator)
  f. checkpoints   0.10  >= 2 explicit checkpoint blocks (scaled below)
  g. dag           0.10  dependency sanity: referenced tasks exist, the
                         graph is acyclic, and at least one real edge is
                         declared (a plan that declares no ordering at all
                         fails sanity for this spec)
  h. verticality   0.10  at least one task spans more than one layer
                         (e.g. storage + interface); purely horizontal
                         plans (all-schema / all-API / all-CLI tasks) fail

Writes the scalar reward to $LOG_DIR/reward.txt (default
/logs/verifier/reward.txt) and a per-check breakdown to score.json.
PLAN_PATH / LOG_DIR env vars override the defaults for local testing.
"""

import json
import os
import pathlib
import re
import shutil

PLAN = pathlib.Path(os.environ.get("PLAN_PATH", "/app/PLAN.md"))
LOGS = pathlib.Path(os.environ.get("LOG_DIR", "/logs/verifier"))

MAX_FILES_PER_TASK = 5
MIN_TASKS = 4
MIN_CHECKPOINTS = 2

WEIGHTS = {
    "task_count": 0.10,
    "acceptance": 0.15,
    "verification": 0.15,
    "dependencies": 0.10,
    "files_budget": 0.20,
    "checkpoints": 0.10,
    "dag": 0.10,
    "verticality": 0.10,
}

HEADING_RE = re.compile(r"^(#{1,6})\s+")
# A task header: "## Task 2: ...", "**Task 2 — ...**", "- [ ] Task 2: ...",
# or "2. Task 2: ...". The id is the first alphanumeric token after "task".
TASK_HEAD_RE = re.compile(
    r"^\s*(?P<marks>#{1,6}\s+|-\s*(?:\[[ xX]\]\s*)?(?:\*\*)?|\d+[.)]\s+|\*\*)?"
    r"\s*task\s+(?P<id>[A-Za-z]?\d+|[A-Za-z])\b\s*[:.)—–\-]",
    re.IGNORECASE,
)
# Numbered section headings are also tasks: "## 1. Extend the model",
# "### 2) Add endpoints", "## 3: Wire the CLI". Heading-only on purpose:
# numbered LIST items ("1. create a row") are step lists, not tasks, and
# "## Checkpoint: ..." / "## Phase 2: ..." do not start with a bare number.
NUMBERED_TASK_HEAD_RE = re.compile(r"^\s*#{1,6}\s+(?P<id>\d+)[:.)]\s+\S")


def task_head(line: str):
    return TASK_HEAD_RE.match(line) or NUMBERED_TASK_HEAD_RE.match(line)
ACCEPT_RE = re.compile(
    r"(?im)^\s*(?:[-*]\s*)?(?:\[[ xX]\]\s*)?(?:\*\*)?\s*"
    r"(acceptance( criteria| conditions)?|done when|definition of done|success criteria)\b"
)
VERIFY_RE = re.compile(
    r"(?im)^\s*(?:[-*]\s*)?(?:\[[ xX]\]\s*)?(?:\*\*)?\s*"
    r"(verification|verify|validation|how to (test|verify)|testing|tests?|test steps|checks?)\b"
)
DEPS_RE = re.compile(
    r"(?im)^\s*(?:[-*]\s*)?(?:\[[ xX]\]\s*)?(?:\*\*)?\s*"
    r"(dependencies|depends on|depends|requires|blocked by|prerequisites?)\b\s*[:\-*]*\s*(?P<rest>.*)$"
)
FILES_LABEL_RE = re.compile(r"(?im)^\s*(?:[-*]\s*)?(?:\*\*)?\s*files?\b.*$")
CHECKPOINT_RE = re.compile(
    r"(?im)^\s*(?:#{1,6}\s+|(?:[-*]\s*)?\*\*)\s*checkpoint\b"
)
# A line that starts a new field inside a task block (ends files collection).
FIELD_LABEL_RE = re.compile(
    r"(?i)^\s*(?:[-*]\s*)?(?:\*\*)?\s*"
    r"(dependencies|verification|acceptance|estimated|estimate|scope|description|notes?|risks?)\b"
)
BACKTICK_RE = re.compile(r"`([^`\n]+)`")
BARE_PATH_RE = re.compile(
    r"[\w.\-]+(?:/[\w.\-]+)*\.(?:py|sql|md|txt|toml|cfg|ini|ya?ml|json|sh|csv|html|css|js|ts|rb)\b"
)


def header_level(line: str) -> int:
    m = HEADING_RE.match(line)
    return len(m.group(1)) if m else 7  # non-heading headers close on any heading


def split_tasks(lines):
    """Return list of (id, block_text). Duplicate ids keep the longest block."""
    starts = [(i, task_head(line)) for i, line in enumerate(lines)]
    starts = [(i, m) for i, m in starts if m]
    blocks = {}
    for pos, (i, m) in enumerate(starts):
        end = len(lines)
        level = header_level(lines[i])
        for j in range(i + 1, len(lines)):
            if task_head(lines[j]):
                end = j
                break
            hm = HEADING_RE.match(lines[j])
            if hm and len(hm.group(1)) <= level:
                end = j
                break
        task_id = m.group("id").lower()
        block = "\n".join(lines[i:end])
        if len(block) > len(blocks.get(task_id, "")):
            blocks[task_id] = block
    return sorted(blocks.items())


def path_tokens(text: str):
    """File-path-looking tokens: backticked paths and bare paths with a
    known source/config extension. Deduped, order preserved."""
    found = []

    def add(tok):
        tok = tok.strip().strip(".,;:)(")
        if tok and not tok.endswith("/") and tok not in found:  # dirs aren't files
            found.append(tok)

    for tok in BACKTICK_RE.findall(text):
        # Backticked tokens count only if the whole token is a file path with
        # a known extension -- this excludes URL routes (`POST /reports`),
        # directories, and commands that merely contain slashes.
        if BARE_PATH_RE.fullmatch(tok.strip()):
            add(tok)
    for tok in BARE_PATH_RE.findall(text):
        add(tok)
    return found


def task_files(block_lines, label_idx):
    """Collect file paths from a 'Files ...' label line plus the bullet or
    plain lines that follow it, stopping at the next field label/heading."""
    tokens = path_tokens(block_lines[label_idx])
    for line in block_lines[label_idx + 1 :]:
        stripped = line.strip()
        if not stripped:
            if tokens:
                break
            continue
        if HEADING_RE.match(line) or FIELD_LABEL_RE.match(line):
            break
        if stripped.startswith("**"):
            break
        tokens.extend(t for t in path_tokens(line) if t not in tokens)
    return tokens


def dep_refs(rest: str):
    """Task ids referenced on a dependencies line. 'None'/'nothing' yields
    an empty set but still counts as declared."""
    refs = set()
    for m in re.finditer(r"(?i)\btasks?\s*#?\s*t?(\d+)\b", rest):
        refs.add(m.group(1))
    for m in re.finditer(r"#?(\d+)\b", rest):
        refs.add(m.group(1))
    return refs


def has_cycle(edges):
    color = {}

    def visit(u):
        color[u] = 1
        for v in edges.get(u, ()):
            if color.get(v) == 1:
                return True
            if color.get(v, 0) == 0 and visit(v):
                return True
        color[u] = 2
        return False

    return any(color.get(u, 0) == 0 and visit(u) for u in edges)


def layer_of(path: str) -> str:
    p = path.lower()
    if "test" in p:
        return "test"
    if re.search(r"model|storage|db|database|migration|schema|persist|\.sql\b", p):
        return "storage"
    if re.search(
        r"api|cli|ui|view|route|endpoint|handler|controller|server|web|front|app\.py|main\.py|cmd",
        p,
    ):
        return "interface"
    return "other"


def main() -> None:
    LOGS.mkdir(parents=True, exist_ok=True)
    if not PLAN.exists():
        (LOGS / "reward.txt").write_text("0\n")
        print(f"MISSING {PLAN}")
        return

    text = PLAN.read_text()
    shutil.copy(PLAN, LOGS / "PLAN.md")
    lines = text.splitlines()
    tasks = split_tasks(lines)

    per_task = []
    edges = {}
    undefined_refs = []
    any_edge = False
    any_vertical = False
    for task_id, block in tasks:
        block_lines = block.splitlines()
        acceptance = bool(ACCEPT_RE.search(block))
        verification = bool(VERIFY_RE.search(block))
        # Dependencies may be inline ("**Dependencies:** Task 1") or listed
        # on the bullet lines that follow the label ("Dependencies:\n- none").
        declared_deps = False
        deps_text = ""
        for idx, line in enumerate(block_lines):
            m = DEPS_RE.match(line)
            if not m:
                continue
            declared_deps = True
            parts = [m.group("rest")]
            for follow in block_lines[idx + 1 :]:
                stripped = follow.strip()
                if not stripped:
                    if parts[-1]:
                        break
                    continue
                if not stripped.startswith(("-", "*")):
                    break
                parts.append(stripped)
            deps_text = " ".join(parts)
            break
        refs = dep_refs(deps_text)
        edges[task_id] = refs
        any_edge = any_edge or bool(refs)
        undefined_refs.extend(sorted(r for r in refs if r not in dict(tasks)))

        files = []
        for idx, line in enumerate(block_lines):
            if FILES_LABEL_RE.match(line):
                files = task_files(block_lines, idx)
                break
        if not files:
            # No explicit files section: fall back to every file path named
            # anywhere in the block (headings, prose, commands). Tolerant of
            # plans that scope tasks by naming files inline; directories
            # (trailing slash) are not counted as files.
            files = path_tokens(block)
        layers = {layer_of(f) for f in files} - {"test"}
        if len(layers) >= 2:
            any_vertical = True
        per_task.append(
            {
                "id": task_id,
                "acceptance": acceptance,
                "verification": verification,
                "dependencies_declared": declared_deps,
                "deps": sorted(refs),
                "files": files,
                "file_count": len(files),
                "within_file_budget": 0 < len(files) <= MAX_FILES_PER_TASK,
            }
        )

    n = max(len(tasks), 1)
    frac = lambda key: round(sum(1 for t in per_task if t[key]) / n, 3) if per_task else 0.0

    checkpoints = len(CHECKPOINT_RE.findall(text))
    dag_ok = (
        bool(tasks) and not undefined_refs and any_edge and not has_cycle(edges)
    )

    checks = {
        # (a) at least MIN_TASKS distinct tasks; scaled below that
        "task_count": min(1.0, len(tasks) / MIN_TASKS),
        # (b) fraction of tasks with an acceptance-criteria section
        "acceptance": frac("acceptance"),
        # (c) fraction of tasks with verification steps
        "verification": frac("verification"),
        # (d) fraction of tasks declaring dependencies ("None" counts)
        "dependencies": frac("dependencies_declared"),
        # (e) fraction of tasks that list files AND stay within the
        #     5-file budget — the XL-task discriminator
        "files_budget": frac("within_file_budget"),
        # (f) at least MIN_CHECKPOINTS explicit checkpoint blocks; scaled
        "checkpoints": min(1.0, checkpoints / MIN_CHECKPOINTS),
        # (g) dependency sanity, all-or-nothing: refs defined, >= 1 edge,
        #     acyclic
        "dag": 1.0 if dag_ok else 0.0,
        # (h) verticality: some task spans 2+ non-test layers
        "verticality": 1.0 if any_vertical else 0.0,
    }

    reward = round(sum(WEIGHTS[k] * checks[k] for k in WEIGHTS), 3)
    (LOGS / "score.json").write_text(
        json.dumps(
            {
                "reward": reward,
                "weights": WEIGHTS,
                "checks": checks,
                "task_count": len(tasks),
                "checkpoints": checkpoints,
                "undefined_refs": undefined_refs,
                "tasks": per_task,
            },
            indent=2,
        )
    )
    (LOGS / "reward.txt").write_text(f"{reward}\n")
    print(json.dumps({"reward": reward, "checks": checks}))


if __name__ == "__main__":
    main()
