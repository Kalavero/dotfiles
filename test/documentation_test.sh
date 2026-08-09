#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=test/test-helper.sh
source "$REPO_DIR/test/test-helper.sh"

while IFS= read -r package || [ -n "$package" ]; do
  [ -n "$package" ] || continue
  assert_contains "\`$package/\`" "$REPO_DIR/README.md"
done < "$REPO_DIR/stow-packages.txt"

assert_symlink "$REPO_DIR/CLAUDE.md"
[ "$(readlink "$REPO_DIR/CLAUDE.md")" = "AGENTS.md" ] || fail 'CLAUDE.md must be a symlink to AGENTS.md'

assert_contains '.agents/skills/dotfiles-package/SKILL.md' "$REPO_DIR/AGENTS.md"
assert_contains 'stow-packages.txt' "$REPO_DIR/.agents/skills/dotfiles-package/SKILL.md"
assert_directory "$REPO_DIR/.agents/skills/dotfiles-package"
[ ! -e "$REPO_DIR/plugins/kalavero/skills/dotfiles-package" ] || fail 'dotfiles-package must remain repository-local'
assert_contains 'herdr/.config/herdr/release-notes.json' "$REPO_DIR/.gitignore"
[ ! -e "$REPO_DIR/herdr/.config/herdr/release-notes.json" ] || fail 'Herdr release notes are a runtime cache, not source configuration'
assert_contains 'session\.json' "$REPO_DIR/herdr/.stow-local-ignore"

pass 'documentation and repository hygiene follow the package registry'

# The README "Common Aliases" table must match aliases/.aliases: every
# documented alias must exist, and a documented expansion must match what the
# alias actually expands to (following shell-alias and git-alias indirection,
# e.g. dcr -> dc -> docker compose, gnb -> git nb -> git checkout -b).
ALIASES_FILE="$REPO_DIR/aliases/.aliases"
GITCONFIG_FILE="$REPO_DIR/git/.gitconfig"
LSP_FILE="$REPO_DIR/neovim/.config/nvim/lua/plugins/lsp.lua"

alias_value() {
  awk -v name="$1" '
    $1 == "alias" {
      line = $0
      sub(/^alias /, "", line)
      sub(/^-g /, "", line)
      if (index(line, name "=") == 1) {
        value = substr(line, length(name) + 2)
        quote = substr(value, 1, 1)
        if (quote == "\047" || quote == "\"") {
          value = substr(value, 2)
          sub(quote ".*$", "", value)
        }
        print value
        exit
      }
    }
  ' "$ALIASES_FILE"
}

git_alias_value() {
  awk -v name="$1" '
    /^\[alias\]/ { in_alias = 1; next }
    /^\[/ { in_alias = 0 }
    in_alias && $1 == name && $2 == "=" {
      sub(/^[^=]*=[ ]*/, "")
      print
      exit
    }
  ' "$GITCONFIG_FILE"
}

expand_command() {
  local command="$1" first sub resolved suffix
  local depth=0
  while [ "$depth" -lt 5 ]; do
    depth=$((depth + 1))
    first="${command%% *}"
    if [ "$first" = "$command" ]; then
      break
    elif [ "$first" = "git" ]; then
      sub="${command#git }"
      sub="${sub%% *}"
      resolved="$(git_alias_value "$sub")"
      [ -n "$resolved" ] || break
      suffix="${command#git "$sub"}"
      command="git $resolved$suffix"
    else
      resolved="$(alias_value "$first")"
      [ -n "$resolved" ] || break
      suffix="${command#"$first"}"
      command="$resolved$suffix"
    fi
  done
  printf '%s' "$command"
}

backticked_words() {
  grep -oE "\`[^\`]+\`" | sed "s/\`//g" || true
}

while IFS= read -r row; do
  [ -n "$row" ] || continue
  name_cell="${row#|}"
  name_cell="${name_cell%%|*}"
  command_cell="${row#*|}"
  command_cell="${command_cell#*|}"
  command_cell="${command_cell%%|*}"

  row_names=()
  while IFS= read -r word; do
    [ -n "$word" ] && row_names+=("$word")
  done < <(printf '%s' "$name_cell" | backticked_words)
  row_commands=()
  while IFS= read -r word; do
    [ -n "$word" ] && row_commands+=("$word")
  done < <(printf '%s' "$command_cell" | backticked_words)

  [ "${#row_commands[@]}" -eq 0 ] || [ "${#row_commands[@]}" -eq "${#row_names[@]}" ] ||
    fail "README alias table row has ${#row_names[@]} aliases but ${#row_commands[@]} commands: $row"

  index=0
  for name in "${row_names[@]}"; do
    [ -n "$name" ] || continue
    value="$(alias_value "$name")"
    [ -n "$value" ] || fail "README documents alias '$name' but aliases/.aliases does not define it"
    if [ "${#row_commands[@]}" -gt 0 ]; then
      documented="${row_commands[$index]}"
      expanded="$(expand_command "$value")"
      [ "$expanded" = "$documented" ] ||
        fail "README documents '$name' as '$documented' but it expands to '$expanded'"
    fi
    index=$((index + 1))
  done
done < <(awk '
  /^### Common Aliases/ { in_section = 1; next }
  in_section && /^\|/ {
    if ($0 ~ /^\| *-/) { past_header = 1; next }
    if (past_header) print
    next
  }
  in_section && past_header { exit }
' "$REPO_DIR/README.md")

pass 'README Common Aliases table matches aliases/.aliases'

# The LSP server list in AGENTS.md must match the servers installed and
# enabled in neovim/.config/nvim/lua/plugins/lsp.lua.
doc_lsp_servers=$(grep -o 'LSP servers: [^.]*' "$REPO_DIR/AGENTS.md" |
  sed 's/.*LSP servers: //' | tr ',' '\n' | sed 's/^ *//; s/ *$//' | sort || true)
enabled_lsp_servers=$(awk '/vim\.lsp\.enable\(\{/,/\}\)/' "$LSP_FILE" |
  grep -oE '"[a-z0-9_]+"' | tr -d '"' | sort || true)
installed_lsp_servers=$(awk '/ensure_installed = \{/,/\}/' "$LSP_FILE" |
  grep -oE '"[a-z0-9_]+"' | tr -d '"' | sort || true)

flatten() {
  paste -sd ' ' -
}

[ "$doc_lsp_servers" = "$enabled_lsp_servers" ] ||
  fail "AGENTS.md LSP servers ($(flatten <<< "$doc_lsp_servers")) do not match vim.lsp.enable ($(flatten <<< "$enabled_lsp_servers"))"
[ "$doc_lsp_servers" = "$installed_lsp_servers" ] ||
  fail "AGENTS.md LSP servers ($(flatten <<< "$doc_lsp_servers")) do not match mason ensure_installed ($(flatten <<< "$installed_lsp_servers"))"

pass 'AGENTS.md LSP server list matches neovim lsp.lua'
