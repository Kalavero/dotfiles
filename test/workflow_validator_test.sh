#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=test/test-helper.sh
source "$REPO_DIR/test/test-helper.sh"

if python3 -c 'import yaml' >/dev/null 2>&1; then
  python3 "$REPO_DIR/script/validate-workflow.py" "$REPO_DIR"
  pass 'workflow manifests and frontmatter are valid'
else
  printf 'ok - workflow validator test skipped because PyYAML is not installed\n'
fi
