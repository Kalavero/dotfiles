#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=test/test-helper.sh
source "$REPO_DIR/test/test-helper.sh"

# Keep this guard before invoking sync.sh. The old script ignores arguments and
# would otherwise operate on the developer's real home directory.
assert_contains '--target-home' "$REPO_DIR/sync.sh"

test_root="$(mktemp -d "${TMPDIR:-/tmp}/kalavero-sync-test.XXXXXX")"
target_home="$test_root/home"
foreign_dir="$test_root/foreign"
mkdir -p "$target_home/.claude/agents" "$target_home/.codex" "$foreign_dir"

cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

cat > "$target_home/.claude/agents/custom-researcher.md" <<'AGENT'
---
name: researcher
description: User-managed researcher.
---

Do not replace this file.
AGENT

cat > "$target_home/.codex/config.toml" <<'TOML'
[projects."/tmp/example"]
trust_level = "trusted"
TOML

"$REPO_DIR/sync.sh" --target-home "$target_home" > "$test_root/first-run.log" 2>&1

assert_symlink "$target_home/.zshrc"
assert_symlink "$target_home/.claude/commands"
assert_file "$target_home/.claude/agents/custom-researcher.md"
[ ! -e "$target_home/.claude/agents/researcher.md" ] || fail 'user-managed agent name should win'
assert_file "$target_home/.config/opencode/agents/planner.md"
assert_contains '  "*": false' "$target_home/.config/opencode/agents/planner.md"
assert_contains '  read: true' "$target_home/.config/opencode/agents/planner.md"
assert_contains '[agents]' "$target_home/.codex/config.toml"
assert_contains 'default_subagent_model = "gpt-5.6-terra"' "$target_home/.codex/config.toml"

"$REPO_DIR/sync.sh" --target-home "$target_home" > "$test_root/second-run.log" 2>&1
if find "$target_home" -name '*.backup.*' -print -quit | grep -q .; then
  fail 'an idempotent second sync should not create backups'
fi

mkdir -p "$target_home/.codex"
ln -s "$foreign_dir" "$target_home/.codex/commands.foreign"
mv "$target_home/.codex/commands" "$target_home/.codex/commands.repo"
mv "$target_home/.codex/commands.foreign" "$target_home/.codex/commands"

"$REPO_DIR/sync.sh" --target-home "$target_home" > "$test_root/conflict-run.log" 2>&1
assert_symlink "$target_home/.codex/commands"
[ "$(readlink "$target_home/.codex/commands")" = "$REPO_DIR/plugins/kalavero/commands" ] || fail 'sync should install the repository link'
find "$target_home/.codex" -maxdepth 1 -name 'commands.backup.*' -type l -print -quit | grep -q . || fail 'foreign symlink should be backed up'

ln -s "$foreign_dir" "$target_home/.vimrc"
"$REPO_DIR/sync.sh" --target-home "$target_home" > "$test_root/foreign-legacy-run.log" 2>&1
[ "$(readlink "$target_home/.vimrc")" = "$foreign_dir" ] || fail 'foreign legacy symlink should be preserved'

dry_home="$test_root/dry-home"
mkdir -p "$dry_home"
"$REPO_DIR/sync.sh" --target-home "$dry_home" --dry-run > "$test_root/dry-run.log" 2>&1
if find "$dry_home" -mindepth 1 -print -quit | grep -q .; then
  fail 'dry-run should not modify the target home'
fi

pass 'sync is isolated, idempotent, conflict-safe, and dry-runnable'
