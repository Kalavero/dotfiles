#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=test/test-helper.sh
source "$REPO_DIR/test/test-helper.sh"

assert_contains 'brew "gnupg"' "$REPO_DIR/Brewfile"
assert_not_contains 'brew "ruby"' "$REPO_DIR/Brewfile"
assert_contains '409B6B1796C275462A1703113804BB82D39DC0E3' "$REPO_DIR/install.sh"
assert_contains '7D2BAF1CF37B13E2069D6956105BD0E739499BDB' "$REPO_DIR/install.sh"
assert_contains 'rvm/rvm/stable/binscripts/rvm-installer' "$REPO_DIR/install.sh"
assert_contains 'gpg --batch --verify' "$REPO_DIR/install.sh"
assert_contains 'rvm use --default --install ruby' "$REPO_DIR/install.sh"
assert_not_contains 'brew --prefix ruby' "$REPO_DIR/install.sh"

rvm_source_line="$(grep -nF "source \"\$HOME/.rvm/scripts/rvm\"" "$REPO_DIR/zsh/.zshrc" | cut -d: -f1)"
bun_path_line="$(grep -nF "export PATH=\"\$BUN_INSTALL/bin:\$PATH\"" "$REPO_DIR/zsh/.zshrc" | cut -d: -f1)"
if [ "$rvm_source_line" -le "$bun_path_line" ]; then
  fail 'RVM must be sourced after runtime PATH changes'
fi

for gem_name in \
  rubocop \
  rubocop-rails \
  rubocop-rspec \
  rubocop-performance \
  brakeman \
  reek \
  packwerk; do
  assert_contains "$gem_name" "$REPO_DIR/install.sh"
done

[ -x "$REPO_DIR/bin/.local/bin/ruby_qa" ] || fail 'ruby_qa must be executable'
assert_contains 'When the task affects Ruby, Rails, RSpec, or Packwerk files' "$REPO_DIR/plugins/kalavero/agents/implementer.md"
assert_contains 'is required only for tasks affecting Ruby, Rails, RSpec, or Packwerk files' "$REPO_DIR/plugins/kalavero/agents/implementer.md"
assert_not_contains 'even when the task is not Ruby-specific' "$REPO_DIR/plugins/kalavero/agents/implementer.md"
assert_not_contains 'mandatory for every task' "$REPO_DIR/plugins/kalavero/agents/implementer.md"
assert_file "$REPO_DIR/plugins/kalavero/agents/reviewer.md"
assert_contains 'Task Description' "$REPO_DIR/plugins/kalavero/agents/reviewer.md"
assert_contains 'Raw Diff' "$REPO_DIR/plugins/kalavero/agents/reviewer.md"
assert_contains 'Architecture Docs' "$REPO_DIR/plugins/kalavero/agents/reviewer.md"
assert_contains "Never include the implementer's report" "$REPO_DIR/plugins/kalavero/commands/implement.md"
assert_contains 'kalavero:reviewer' "$REPO_DIR/plugins/kalavero/commands/implement.md"

pass 'Ruby QA installation and independent review workflow are wired together'
