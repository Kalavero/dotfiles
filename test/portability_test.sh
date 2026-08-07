#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=test/test-helper.sh
source "$REPO_DIR/test/test-helper.sh"

if grep -RqsE '/Users/[^/]+/' "$REPO_DIR/zsh" "$REPO_DIR/aliases" "$REPO_DIR/git"; then
  fail 'tracked shell and Git configuration must not contain a user-specific home path'
fi

assert_contains "\$BUN_INSTALL/_bun" "$REPO_DIR/zsh/.zshrc"
assert_contains 'brew "kimi-code"' "$REPO_DIR/Brewfile"
assert_contains "\$HOME/.kimi-code/bin" "$REPO_DIR/zsh/.zshenv"
assert_not_contains '/opt/homebrew/bin/brew shellenv' "$REPO_DIR/install.sh"

pass 'tracked configuration is independent of the current machine and Homebrew architecture'
