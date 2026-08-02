#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=test/test-helper.sh
source "$REPO_DIR/test/test-helper.sh"

workflow="$REPO_DIR/.github/workflows/check.yml"
assert_contains 'cache: pip' "$workflow"
assert_contains 'cache-dependency-path: requirements-dev.txt' "$workflow"

pass 'CI pip caching tracks the development requirements file'
