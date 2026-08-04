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
assert_contains '.agents/skills/skill-benchmark/SKILL.md' "$REPO_DIR/AGENTS.md"
assert_contains 'stow-packages.txt' "$REPO_DIR/.agents/skills/dotfiles-package/SKILL.md"
for local_skill in dotfiles-package skill-benchmark; do
  assert_directory "$REPO_DIR/.agents/skills/$local_skill"
  [ ! -e "$REPO_DIR/plugins/kalavero/skills/$local_skill" ] || fail "$local_skill must remain repository-local"
done
assert_contains 'herdr/.config/herdr/release-notes.json' "$REPO_DIR/.gitignore"
[ ! -e "$REPO_DIR/herdr/.config/herdr/release-notes.json" ] || fail 'Herdr release notes are a runtime cache, not source configuration'

pass 'documentation and repository hygiene follow the package registry'
