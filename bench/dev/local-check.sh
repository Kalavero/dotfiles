#!/usr/bin/env bash
# local-check.sh <task-dir> — build the task image and run oracle + verifier
# the same way benchflow does (mounts at /oracle, /verifier, logs at /logs),
# without needing benchflow. Exits non-zero unless reward is 1.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TASK_DIR="$REPO_DIR/${1#"$REPO_DIR"/}"
TASK="$(basename "$TASK_DIR")"
IMAGE="bf-dev__${TASK}"

echo "==> building $IMAGE"
docker build -q -t "$IMAGE" "$TASK_DIR/environment" >/dev/null

echo "==> running oracle + verifier"
docker run --rm \
  -v "$TASK_DIR/oracle:/oracle:ro" \
  -v "$TASK_DIR/verifier:/verifier:ro" \
  --entrypoint bash \
  "$IMAGE" -c '
    mkdir -p /logs/verifier
    bash /oracle/solve.sh
    bash /verifier/test.sh
    echo "--- score.json (if any) ---"
    cat /logs/verifier/score.json 2>/dev/null || true
    echo "---"
    cat /logs/verifier/reward.txt
  '
