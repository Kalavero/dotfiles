#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=test/test-helper.sh
source "$REPO_DIR/test/test-helper.sh"

test_root="$(mktemp -d "${TMPDIR:-/tmp}/kalavero-codex-test.XXXXXX")"
cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

cat > "$test_root/config.toml" <<'TOML'
[projects."/tmp/example"]
trust_level = "trusted"
TOML

node "$REPO_DIR/script/configure-codex.mjs" "$test_root/config.toml" "$test_root/candidate.toml" 'gpt-5.6-terra'
assert_contains '[projects."/tmp/example"]' "$test_root/candidate.toml"
assert_contains '[agents]' "$test_root/candidate.toml"
assert_contains '# Managed by kalavero sync.sh' "$test_root/candidate.toml"
assert_contains 'default_subagent_model = "gpt-5.6-terra"' "$test_root/candidate.toml"

cp "$test_root/candidate.toml" "$test_root/managed.toml"
node "$REPO_DIR/script/configure-codex.mjs" "$test_root/managed.toml" "$test_root/updated.toml" 'gpt-next'
assert_contains 'default_subagent_model = "gpt-next"' "$test_root/updated.toml"

cat > "$test_root/explicit.toml" <<'TOML'
[agents]
default_subagent_model = "user-choice"
TOML

node "$REPO_DIR/script/configure-codex.mjs" "$test_root/explicit.toml" "$test_root/skipped.toml" 'gpt-5.6-terra'
[ ! -e "$test_root/skipped.toml" ] || fail 'an explicit user setting should not produce a candidate'

pass 'Codex configuration preserves explicit overrides and updates managed values'
