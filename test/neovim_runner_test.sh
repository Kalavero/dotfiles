#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=test/test-helper.sh
source "$REPO_DIR/test/test-helper.sh"

command -v nvim >/dev/null 2>&1 || fail 'Neovim is required for runner tests'

TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

run_nvim_test() {
  NVIM_LOG_FILE="$TEST_TMP/nvim.log" \
    XDG_CACHE_HOME="$TEST_TMP/cache" \
    XDG_DATA_HOME="$TEST_TMP/data" \
    XDG_STATE_HOME="$TEST_TMP/state" \
    nvim --headless -u NONE -i NONE -l "$1"
}

cd "$REPO_DIR"
run_nvim_test test/neovim_herdr_runner_test.lua
run_nvim_test test/neovim_herdr_config_test.lua
run_nvim_test test/neovim_tmux_runner_test.lua

pass 'Neovim supports Herdr panes without regressing tmux runners'
