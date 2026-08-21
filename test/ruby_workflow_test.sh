#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=test/test-helper.sh
source "$REPO_DIR/test/test-helper.sh"

assert_contains 'brew "ruby"' "$REPO_DIR/Brewfile"
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
assert_contains 'ruby_qa' "$REPO_DIR/plugins/kalavero/agents/implementer.md"
assert_file "$REPO_DIR/plugins/kalavero/agents/reviewer.md"
assert_contains 'Task Description' "$REPO_DIR/plugins/kalavero/agents/reviewer.md"
assert_contains 'Raw Diff' "$REPO_DIR/plugins/kalavero/agents/reviewer.md"
assert_contains 'Architecture Docs' "$REPO_DIR/plugins/kalavero/agents/reviewer.md"
assert_contains "Never include the implementer's report" "$REPO_DIR/plugins/kalavero/commands/implement.md"
assert_contains 'kalavero:reviewer' "$REPO_DIR/plugins/kalavero/commands/implement.md"

pass 'Ruby QA installation and independent review workflow are wired together'
