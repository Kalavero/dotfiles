#!/usr/bin/env python3
"""Verifier for the incremental-cli-slices task.

Two components:

  acceptance (weight 0.4)
    - hidden acceptance tests in /verifier/acceptance exercise the real CLI
      against the final state (fraction passed, weight 0.75 of the component)
    - the visible suite in /app/tests is green in the final working tree
      (weight 0.25 of the component)

  cadence / green-per-commit (weight 0.6)
    - the agent's commits on top of the root commit are replayed: each
      revision is extracted with `git archive` into a temp dir (read-only;
      /app's own checkout is never touched) and the visible test suite *as it
      existed at that commit* is run there. A commit is green iff pytest
      exits 0 and ran at least one test; a commit with no tests at all counts
      as NOT green.
    - cadence = gate * green_fraction * clean_factor, where
        gate          = 1.0 if >= 3 non-merge commits, else 0.5 * n / 3
        green_fraction= fraction of the agent's commits that replay green
        clean_factor  = 1.0 if no tracked file has uncommitted modifications,
                        else 0.5 (untracked data files are ignored)

Writes /logs/verifier/reward.txt and /logs/verifier/score.json with the
per-commit replay breakdown.
"""

import json
import pathlib
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

APP = pathlib.Path("/app")
VERIFIER = pathlib.Path("/verifier")
LOGS = pathlib.Path("/logs/verifier")

MIN_COMMITS = 3
W_ACCEPTANCE = 0.4
W_CADENCE = 0.6


def sh(args, cwd=None):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True)


def git(*args):
    return sh(["git", "-C", str(APP), *args])


def parse_junit(path):
    total = failures = errors = 0
    try:
        tree = ET.parse(str(path))
    except (OSError, ET.ParseError):
        return 0, 0, 1
    for suite in tree.getroot().iter("testsuite"):
        total += int(suite.get("tests", 0))
        failures += int(suite.get("failures", 0))
        errors += int(suite.get("errors", 0))
    return total, failures, errors


def run_pytest(cwd, target, junit_path):
    """Run pytest; return dict with tests run, failures, errors, exit code."""
    result = sh(
        [sys.executable, "-m", "pytest", target, "-q", f"--junitxml={junit_path}"],
        cwd=cwd,
    )
    total, failures, errors = parse_junit(junit_path)
    return {
        "exit_code": result.returncode,
        "tests": total,
        "failures": failures,
        "errors": errors,
        "green": result.returncode == 0 and total >= 1,
    }


def replay_commits():
    """Replay each agent commit in a temp dir; return (commits_report, n)."""
    root_out = git("rev-list", "--max-parents=0", "HEAD")
    if root_out.returncode != 0 or not root_out.stdout.strip():
        return [{"error": "no git root commit found"}], 0
    root = root_out.stdout.split()[0]

    revs = git("rev-list", "--reverse", "--no-merges", f"{root}..HEAD")
    shas = [s for s in revs.stdout.split() if s]

    report = []
    for sha in shas:
        message = git("log", "-1", "--format=%s", sha).stdout.strip()
        entry = {"sha": sha[:10], "message": message}
        with tempfile.TemporaryDirectory(prefix="replay-") as tmp:
            archive = subprocess.run(
                ["git", "-C", str(APP), "archive", sha], capture_output=True
            )
            extract = subprocess.run(
                ["tar", "-x", "-C", tmp], input=archive.stdout, capture_output=True
            )
            if archive.returncode != 0 or extract.returncode != 0:
                entry.update(green=False, reason="archive failed")
                report.append(entry)
                continue
            if not (pathlib.Path(tmp) / "tests").is_dir():
                entry.update(green=False, reason="no tests directory at this commit",
                             tests=0, exit_code=None)
                report.append(entry)
                continue
            result = run_pytest(tmp, "tests", pathlib.Path(tmp) / "junit.xml")
            entry.update(result)
            if not result["green"] and result["tests"] == 0 and result["exit_code"] != 0:
                entry["reason"] = "no tests ran" if result["exit_code"] == 5 else "pytest failed"
            elif not result["green"]:
                entry["reason"] = "pytest failed"
        report.append(entry)
    return report, len(shas)


def working_tree_clean():
    """True if no tracked file has staged or unstaged modifications.

    Untracked files (notes.json data, scratch files) are ignored.
    """
    status = git("status", "--porcelain")
    dirty = [
        line for line in status.stdout.splitlines()
        if line and not line.startswith("??")
    ]
    return not dirty, dirty


def main():
    LOGS.mkdir(parents=True, exist_ok=True)

    # --- acceptance: hidden suite against the final state -------------------
    hidden = {"tests": 0, "failures": 0, "errors": 1, "green": False}
    with tempfile.TemporaryDirectory(prefix="acceptance-") as tmp:
        acceptance_src = VERIFIER / "acceptance"
        if acceptance_src.is_dir():
            sh(["cp", "-R", str(acceptance_src) + "/.", tmp])
            hidden = run_pytest(tmp, ".", pathlib.Path(tmp) / "junit.xml")
    hidden_total = hidden["tests"]
    hidden_passed = hidden_total - hidden["failures"] - hidden["errors"]
    hidden_fraction = (hidden_passed / hidden_total) if hidden_total else 0.0

    # --- acceptance: visible suite green in the final working tree ----------
    final_visible = run_pytest(str(APP), "tests", "/tmp/final-visible-junit.xml")

    acceptance_score = 0.75 * hidden_fraction + 0.25 * (1.0 if final_visible["green"] else 0.0)

    # --- cadence: git replay -------------------------------------------------
    commits, n_commits = replay_commits()
    n_green = sum(1 for c in commits if c.get("green"))
    green_fraction = (n_green / n_commits) if n_commits else 0.0
    gate = 1.0 if n_commits >= MIN_COMMITS else 0.5 * n_commits / MIN_COMMITS
    clean, dirty = working_tree_clean()
    clean_factor = 1.0 if clean else 0.5
    cadence_score = gate * green_fraction * clean_factor

    reward = W_ACCEPTANCE * acceptance_score + W_CADENCE * cadence_score
    reward = max(0.0, min(1.0, reward))

    score = {
        "reward": round(reward, 3),
        "weights": {"acceptance": W_ACCEPTANCE, "cadence": W_CADENCE},
        "acceptance": {
            "score": round(acceptance_score, 3),
            "hidden_tests": hidden_total,
            "hidden_passed": hidden_passed,
            "hidden_fraction": round(hidden_fraction, 3),
            "final_visible_green": final_visible["green"],
            "final_visible_tests": final_visible["tests"],
        },
        "cadence": {
            "score": round(cadence_score, 3),
            "commits_on_top_of_initial": n_commits,
            "min_commits_required": MIN_COMMITS,
            "gate": round(gate, 3),
            "green_fraction": round(green_fraction, 3),
            "clean_working_tree": clean,
            "dirty_tracked_files": dirty,
            "replay": commits,
        },
    }
    (LOGS / "score.json").write_text(json.dumps(score, indent=2) + "\n")
    (LOGS / "replay.json").write_text(json.dumps(commits, indent=2) + "\n")
    (LOGS / "reward.txt").write_text(f"{round(reward, 3)}\n")
    print(json.dumps({"reward": round(reward, 3), "commits": n_commits,
                      "green": n_green, "hidden": f"{hidden_passed}/{hidden_total}"}))


if __name__ == "__main__":
    main()
