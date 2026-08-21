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
mkdir -p \
  "$target_home/.claude/agents" \
  "$target_home/.codex/skills/.system/system-sentinel" \
  "$target_home/.agents/skills/personal-skill" \
  "$target_home/.agents/skills/tad" \
  "$target_home/.claude/skills/personal-skill" \
  "$target_home/.config/opencode/skills/personal-skill" \
  "$target_home/.pi/agent/skills/personal-skill" \
  "$foreign_dir"

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
chmod 600 "$target_home/.codex/config.toml"

cat > "$target_home/.codex/skills/.system/system-sentinel/SKILL.md" <<'SKILL'
---
name: system-sentinel
description: Represents a Codex-managed system skill.
---

Codex owns this file.
SKILL

for skill_root in \
  "$target_home/.agents/skills" \
  "$target_home/.claude/skills" \
  "$target_home/.config/opencode/skills" \
  "$target_home/.pi/agent/skills"; do
  cat > "$skill_root/personal-skill/SKILL.md" <<'SKILL'
---
name: personal-skill
description: Represents a user-managed skill.
---

The user owns this file.
SKILL
done

cat > "$target_home/.agents/skills/tad/SKILL.md" <<'SKILL'
---
name: tad
description: Represents a conflicting user-managed skill.
---

The user-managed version wins.
SKILL

ln -s "$REPO_DIR/plugins/kalavero/skills/removed-skill" "$target_home/.agents/skills/removed-skill"
ln -s "$REPO_DIR/plugins/kalavero/skills/agent-brief" "$target_home/.codex/skills/agent-brief"

"$REPO_DIR/sync.sh" --target-home "$target_home" > "$test_root/first-run.log" 2>&1

assert_symlink "$target_home/.zshrc"
assert_symlink "$target_home/.local/bin/ruby_qa"
assert_symlink "$target_home/.claude/commands"
assert_file "$target_home/.claude/agents/custom-researcher.md"
[ ! -e "$target_home/.claude/agents/researcher.md" ] || fail 'user-managed agent name should win'
assert_file "$target_home/.config/opencode/agents/planner.md"
assert_contains '  "*": false' "$target_home/.config/opencode/agents/planner.md"
assert_contains '  read: true' "$target_home/.config/opencode/agents/planner.md"
assert_contains '[agents]' "$target_home/.codex/config.toml"
assert_contains 'default_subagent_model = "gpt-5.6-terra"' "$target_home/.codex/config.toml"
[ "$(stat -c '%a' "$target_home/.codex/config.toml" 2>/dev/null || stat -f '%Lp' "$target_home/.codex/config.toml")" = "600" ] || fail 'sync should preserve existing config.toml permissions'
assert_file "$target_home/.codex/skills/.system/system-sentinel/SKILL.md"
[ ! -L "$target_home/.codex/skills" ] || fail 'sync should not own the Codex skills directory'
for skill_root in \
  "$target_home/.agents/skills" \
  "$target_home/.claude/skills" \
  "$target_home/.config/opencode/skills" \
  "$target_home/.pi/agent/skills"; do
  assert_file "$skill_root/personal-skill/SKILL.md"
  assert_symlink "$skill_root/agent-brief"
  [ "$(readlink "$skill_root/agent-brief")" = "$REPO_DIR/plugins/kalavero/skills/agent-brief" ] || fail 'sync should link each Kalavero skill individually'
  [ ! -e "$skill_root/.system" ] || fail 'sync should not publish Codex system skills'
done
assert_file "$target_home/.agents/skills/tad/SKILL.md"
[ ! -L "$target_home/.agents/skills/tad" ] || fail 'a conflicting user-managed skill should be preserved'
assert_contains 'The user-managed version wins.' "$target_home/.agents/skills/tad/SKILL.md"
if [ -e "$target_home/.agents/skills/removed-skill" ] || [ -L "$target_home/.agents/skills/removed-skill" ]; then fail 'stale repository-owned skill links should be removed'; fi
if [ -e "$target_home/.codex/skills/agent-brief" ] || [ -L "$target_home/.codex/skills/agent-brief" ]; then fail 'legacy Kalavero skill links should be removed from the Codex skills directory'; fi

"$REPO_DIR/sync.sh" --target-home "$target_home" > "$test_root/second-run.log" 2>&1
# -L follows folded directory links so backups inside them (which would live
# in the repository) are caught too.
if find -L "$target_home" -name '*.backup.*' -print -quit | grep -q .; then
  fail 'an idempotent second sync should not create backups'
fi

mkdir -p "$target_home/.codex"
ln -s "$foreign_dir" "$target_home/.codex/commands.foreign"
mv "$target_home/.codex/commands" "$target_home/.codex/commands.repo"
mv "$target_home/.codex/commands.foreign" "$target_home/.codex/commands"

"$REPO_DIR/sync.sh" --target-home "$target_home" > "$test_root/conflict-run.log" 2>&1
[ "$(readlink "$target_home/.codex/commands")" = "$foreign_dir" ] || fail 'user-managed symlink should be preserved'
assert_contains 'Preserving user-managed symlink: ~/.codex/commands' "$test_root/conflict-run.log"

ln -s "$foreign_dir" "$target_home/.vimrc"
"$REPO_DIR/sync.sh" --target-home "$target_home" > "$test_root/foreign-legacy-run.log" 2>&1
[ "$(readlink "$target_home/.vimrc")" = "$foreign_dir" ] || fail 'foreign legacy symlink should be preserved'

legacy_home="$test_root/legacy-home"
mkdir -p \
  "$legacy_home/.claude" \
  "$legacy_home/.agents" \
  "$legacy_home/.config/opencode" \
  "$legacy_home/.pi/agent" \
  "$legacy_home/.codex"
for skill_root in \
  "$legacy_home/.claude/skills" \
  "$legacy_home/.agents/skills" \
  "$legacy_home/.config/opencode/skills" \
  "$legacy_home/.pi/agent/skills" \
  "$legacy_home/.codex/skills"; do
  ln -s "$REPO_DIR/plugins/kalavero/skills" "$skill_root"
done

"$REPO_DIR/sync.sh" --target-home "$legacy_home" > "$test_root/legacy-skills-run.log" 2>&1
for skill_root in \
  "$legacy_home/.claude/skills" \
  "$legacy_home/.agents/skills" \
  "$legacy_home/.config/opencode/skills" \
  "$legacy_home/.pi/agent/skills"; do
  assert_directory "$skill_root"
  [ ! -L "$skill_root" ] || fail 'legacy skills root links should become real directories'
  assert_symlink "$skill_root/agent-brief"
  [ ! -e "$skill_root/.system" ] || fail 'legacy migration should not republish Codex system skills'
done
if [ -e "$legacy_home/.codex/skills" ] || [ -L "$legacy_home/.codex/skills" ]; then fail 'legacy Codex skills root should return to Codex ownership'; fi

dry_home="$test_root/dry-home"
mkdir -p "$dry_home"
"$REPO_DIR/sync.sh" --target-home "$dry_home" --dry-run > "$test_root/dry-run.log" 2>&1
if find "$dry_home" -mindepth 1 -print -quit | grep -q .; then
  fail 'dry-run should not modify the target home'
fi

stow_conflict_home="$test_root/stow-conflict-home"
mkdir -p "$stow_conflict_home"
echo '# user-managed zshrc' > "$stow_conflict_home/.zshrc"

"$REPO_DIR/sync.sh" --target-home "$stow_conflict_home" > "$test_root/stow-conflict-run.log" 2>&1
assert_symlink "$stow_conflict_home/.zshrc"
assert_symlink "$stow_conflict_home/.gitconfig"
assert_symlink "$stow_conflict_home/.tmux.conf"
zshrc_backup="$(find "$stow_conflict_home" -maxdepth 1 -name '.zshrc.backup.*' -print -quit)"
[ -n "$zshrc_backup" ] || fail 'a real .zshrc should be backed up before stowing'
assert_contains '# user-managed zshrc' "$zshrc_backup"

pass 'sync is isolated, idempotent, conflict-safe, and dry-runnable'
