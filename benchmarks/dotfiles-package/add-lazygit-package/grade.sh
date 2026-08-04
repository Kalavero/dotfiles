#!/usr/bin/env bash

set -euo pipefail

WORKSPACE="${1:?workspace path is required}"

grep -Fxq 'lazygit' "$WORKSPACE/stow-packages.txt"
grep -Fxq 'brew "lazygit"' "$WORKSPACE/Brewfile"
grep -Fq '`lazygit/`' "$WORKSPACE/README.md"
grep -Fq '`lazygit/`' "$WORKSPACE/CLAUDE.md"
grep -Fq 'showIcons: true' "$WORKSPACE/lazygit/.config/lazygit/config.yml"
grep -Eq "editPreset: ['\"]?nvim['\"]?" "$WORKSPACE/lazygit/.config/lazygit/config.yml"

if rg -n -i '(api[_-]?key|secret|token|password|acme corp)' "$WORKSPACE/lazygit"; then
  echo 'Lazygit package must not contain secrets or employer-specific configuration.' >&2
  exit 1
fi
