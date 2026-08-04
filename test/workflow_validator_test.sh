#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=test/test-helper.sh
source "$REPO_DIR/test/test-helper.sh"

PYTHON_BIN="python3"
if [ -x "$REPO_DIR/.venv/bin/python3" ]; then
  PYTHON_BIN="$REPO_DIR/.venv/bin/python3"
fi

if "$PYTHON_BIN" -c 'import yaml' >/dev/null 2>&1; then
  "$PYTHON_BIN" "$REPO_DIR/script/validate-workflow.py" "$REPO_DIR"

  test_root="$(mktemp -d "${TMPDIR:-/tmp}/kalavero-workflow-validator-test.XXXXXX")"
  trap 'rm -rf "$test_root"' EXIT
  fixture_root="$test_root/repo"
  mkdir -p \
    "$fixture_root/.claude-plugin" \
    "$fixture_root/plugins/kalavero/.claude-plugin" \
    "$fixture_root/plugins/kalavero/skills/.system"
  cp "$REPO_DIR/.claude-plugin/marketplace.json" "$fixture_root/.claude-plugin/marketplace.json"
  cp "$REPO_DIR/plugins/kalavero/.claude-plugin/plugin.json" "$fixture_root/plugins/kalavero/.claude-plugin/plugin.json"

  if "$PYTHON_BIN" "$REPO_DIR/script/validate-workflow.py" "$fixture_root" >/dev/null 2>&1; then
    fail 'workflow validator should reject vendored system skills'
  fi

  pass 'workflow manifests and frontmatter are valid'
else
  printf 'ok - workflow validator test skipped because PyYAML is not installed\n'
fi
