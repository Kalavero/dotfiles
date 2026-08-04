#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=test/test-helper.sh
source "$REPO_DIR/test/test-helper.sh"

while IFS= read -r package || [ -n "$package" ]; do
  [ -n "$package" ] || continue
  assert_directory "$REPO_DIR/$package"
done < "$REPO_DIR/stow-packages.txt"

assert_contains 'stow-packages.txt' "$REPO_DIR/sync.sh"
assert_contains 'stow-packages.txt' "$REPO_DIR/Dockerfile"

pass 'the package registry drives sync and Docker validation'
