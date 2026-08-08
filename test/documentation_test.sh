#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=test/test-helper.sh
source "$REPO_DIR/test/test-helper.sh"

while IFS= read -r package || [ -n "$package" ]; do
  [ -n "$package" ] || continue
  assert_contains "\`$package/\`" "$REPO_DIR/README.md"
  assert_contains "\`$package/\`" "$REPO_DIR/CLAUDE.md"
done < "$REPO_DIR/stow-packages.txt"

assert_contains '.agents/skills/dotfiles-package/SKILL.md' "$REPO_DIR/AGENTS.md"
assert_contains 'stow-packages.txt' "$REPO_DIR/.agents/skills/dotfiles-package/SKILL.md"
assert_directory "$REPO_DIR/.agents/skills/dotfiles-package"
[ ! -e "$REPO_DIR/plugins/kalavero/skills/dotfiles-package" ] || fail 'dotfiles-package must remain repository-local'
assert_contains 'herdr/.config/herdr/release-notes.json' "$REPO_DIR/.gitignore"
[ ! -e "$REPO_DIR/herdr/.config/herdr/release-notes.json" ] || fail 'Herdr release notes are a runtime cache, not source configuration'
assert_contains 'session\.json' "$REPO_DIR/herdr/.stow-local-ignore"

pass 'documentation and repository hygiene follow the package registry'
