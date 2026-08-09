#!/usr/bin/env bash
# bench/run.sh — run the kalavero skills A/B benchmark protocol.
#
# Subcommands:
#   list                     List task packages.
#   oracle <task|all>        Oracle gate: every task's oracle must score 1.0.
#   ceiling <task|all>       Ceiling check: no-skill arm, gpt-5.4-mini, 1 rep.
#                            A full-reward no-skill result means the task is
#                            too easy and must be hardened before the matrix.
#   matrix [task...|all]     Full A/B protocol per task: models x arms x reps,
#                            arms strictly sequential with the docker image
#                            removed between arms (bf__<task>:latest is keyed
#                            by task name only — concurrent arms contaminate).
#   gate <task|all>          oracle + ceiling; the entry bar for the matrix.
#   analyze                  Aggregate rewards and token usage from jobs dirs.
#
# Environment:
#   BENCH_BIN       path to the benchflow `bench` CLI (default: `bench` on PATH)
#   BENCH_JOBS_DIR  jobs root (default: bench/jobs)
#   BENCH_MODELS    space-separated model list (default: "gpt-5.4-mini gpt-5.5")
#   BENCH_REPS      repetitions per arm (default: 4)
#
# Different tasks may be run concurrently from separate shells; arms of the
# SAME task must never overlap (see bench/README.md, gotcha 3).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TASKS_DIR="$REPO_DIR/bench/tasks"
JOBS_ROOT="${BENCH_JOBS_DIR:-$REPO_DIR/bench/jobs}"
RESULTS_DIR="$REPO_DIR/bench/results"
BENCH="${BENCH_BIN:-$(command -v bench || true)}"
read -r -a MODELS <<< "${BENCH_MODELS:-gpt-5.4-mini gpt-5.5}"
REPS="${BENCH_REPS:-4}"
CEILING_MODEL="gpt-5.4-mini"

usage() {
  sed -n '2,30p' "$0"
  exit 2
}

require_bench() {
  if [ -z "$BENCH" ] || [ ! -x "$BENCH" ]; then
    echo "benchflow CLI not found. Set BENCH_BIN or install per bench/README.md." >&2
    exit 1
  fi
  # benchflow 0.6.6's pinned codex-acp 0.0.45 is broken against the current
  # Codex backend; warn unless the install was patched (bench/README.md).
  local pkg
  pkg="$(dirname "$(readlink -f "$BENCH")")/../lib"
  if grep -rq 'codex-acp@0.0.45' "$pkg"/*/site-packages/benchflow/agents/registry.py 2>/dev/null; then
    echo "WARNING: unpatched benchflow (codex-acp 0.0.45 pin) — codex runs will fail." >&2
    echo "Run: python3 $REPO_DIR/bench/dev/patch_benchflow.py" >&2
  fi
}

resolve_tasks() {
  if [ "${1:-all}" = "all" ]; then
    find "$TASKS_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
  else
    for t in "$@"; do
      [ -d "$TASKS_DIR/$t" ] || { echo "unknown task: $t" >&2; exit 2; }
      echo "$t"
    done
  fi
}

image_name() {
  # benchflow tags the built image bf__<task-name>:latest, keyed by task name
  # only (sandbox/docker.py). Must be removed whenever the skill mode changes.
  printf 'bf__%s:latest' "$1"
}

rmi_task_image() {
  docker rmi "$(image_name "$1")" >/dev/null 2>&1 || true
}

run_eval() {
  # run_eval <task> <agent> <model|-> <skill-mode> <jobs-dir>
  local task="$1" agent="$2" model="$3" mode="$4" jobs_dir="$5"
  local args=(eval run
    --tasks-dir "$TASKS_DIR/$task"
    --agent "$agent"
    --sandbox docker
    --jobs-dir "$jobs_dir")
  [ "$model" = "-" ] || args+=(--model "$model")
  [ -z "$mode" ] || args+=(--skill-mode "$mode")
  echo "==> $task | agent=$agent model=$model mode=${mode:-default} jobs=$jobs_dir"
  "$BENCH" "${args[@]}"
}

latest_reward() {
  # Print the reward of the most recent rollout under a jobs dir.
  local latest
  latest="$(find "$1" -name result.json -exec ls -t {} + 2>/dev/null | head -1)"
  [ -n "$latest" ] || { echo "?"; return; }
  python3 - "$latest" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    print("?"); raise SystemExit
for key in ("reward", "score"):
    if isinstance(data, dict) and key in data:
        print(data[key]); break
    elif isinstance(data, dict) and isinstance(data.get("rewards"), dict) and key in data["rewards"]:
        print(data["rewards"][key]); break
    elif isinstance(data, dict) and isinstance(data.get("verifier"), dict) and key in data["verifier"]:
        print(data["verifier"][key]); break
else:
    print("?")
PY
}

cmd_oracle() {
  require_bench
  local task reward fail=0
  for task in $(resolve_tasks "$@"); do
    rmi_task_image "$task"
    # Fresh jobs dir per invocation: benchflow resumes (skips) tasks with an
    # existing rollout in the jobs dir, which would silently reuse stale
    # results after a task is edited.
    run_eval "$task" oracle - "" "$JOBS_ROOT/$task-oracle/$(date +%s)"
    reward="$(latest_reward "$JOBS_ROOT/$task-oracle")"
    echo "==> $task oracle reward: $reward"
    [ "$reward" = "1.0" ] || [ "$reward" = "1" ] || { echo "ORACLE GATE FAILED: $task (reward $reward)"; fail=1; }
  done
  [ "$fail" -eq 0 ] && echo "oracle gate: all passed"
  return "$fail"
}

cmd_ceiling() {
  require_bench
  local task reward fail=0
  for task in $(resolve_tasks "$@"); do
    rmi_task_image "$task"
    run_eval "$task" codex-acp "$CEILING_MODEL" no-skill "$JOBS_ROOT/$task-$CEILING_MODEL-no-skill-ceiling/$(date +%s)"
    reward="$(latest_reward "$JOBS_ROOT/$task-$CEILING_MODEL-no-skill-ceiling")"
    echo "==> $task ceiling-check reward (no-skill, $CEILING_MODEL): $reward"
    case "$reward" in
      1|1.0|1.00) echo "CEILING: $task maxed without the skill — harden before matrix"; fail=1 ;;
    esac
  done
  [ "$fail" -eq 0 ] && echo "ceiling check: no task ceilinged"
  return "$fail"
}

cmd_matrix() {
  require_bench
  local task model mode rep
  for task in $(resolve_tasks "$@"); do
    for model in "${MODELS[@]}"; do
      for mode in no-skill with-skill; do
        # Image-tag race guard: never let a stale image from the other arm
        # (or an earlier mode) survive a mode switch.
        rmi_task_image "$task"
        for rep in $(seq 1 "$REPS"); do
          run_eval "$task" codex-acp "$model" "$mode" \
            "$JOBS_ROOT/$task-$model-$mode/rep-$rep"
        done
      done
    done
    rmi_task_image "$task"
  done
}

cmd_gate() {
  cmd_oracle "$@" && cmd_ceiling "$@"
}

cmd_analyze() {
  python3 "$REPO_DIR/bench/analyze.py" --jobs-root "$JOBS_ROOT" --out-dir "$RESULTS_DIR"
}

case "${1:-}" in
  list) resolve_tasks all ;;
  oracle) shift; cmd_oracle "$@" ;;
  ceiling) shift; cmd_ceiling "$@" ;;
  matrix) shift; cmd_matrix "$@" ;;
  gate) shift; cmd_gate "$@" ;;
  analyze) cmd_analyze ;;
  *) usage ;;
esac
