#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=test/test-helper.sh
source "$REPO_DIR/test/test-helper.sh"

workflow="$REPO_DIR/.github/workflows/check.yml"
assert_contains 'branches: [main]' "$workflow"
assert_contains 'cache: pip' "$workflow"
assert_contains 'cache-dependency-path: requirements-dev.txt' "$workflow"
assert_contains 'sudo apt-get update && sudo apt-get install -y shellcheck stow zsh neovim' "$workflow"
assert_contains 'brew install shellcheck stow neovim' "$workflow"

pass 'CI runs once per PR with all check dependencies'
