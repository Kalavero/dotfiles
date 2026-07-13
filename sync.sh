#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Syncing Kalavero Dotfiles"
echo ""

link_if_needed() {
  local source="$DOTFILES_DIR/$1"
  local target="$HOME/$2"

  if [ -L "$target" ]; then
    [ "$(readlink "$target")" = "$source" ] && return 0
    rm "$target"
  elif [ -e "$target" ]; then
    local backup="$target.backup.$(date +%Y%m%d%H%M%S)"
    echo "  Backing up existing ~/$2 -> $(basename "$backup")"
    mv "$target" "$backup"
  fi

  mkdir -p "$(dirname "$target")"
  ln -s "$source" "$target"
}

remove_old_symlink() {
  if [ -L "$HOME/$1" ]; then
    echo "  Removing old symlink: ~/$1"
    rm "$HOME/$1"
  fi
}

backup_if_conflict() {
  [ -L "$HOME/$1" ] && return 0
  [ -e "$HOME/$1" ] || return 0
  local backup="$HOME/$1.backup.$(date +%Y%m%d%H%M%S)"
  echo "  Backing up existing ~/$1 -> $(basename "$backup")"
  mv "$HOME/$1" "$backup"
}

echo "==> Checking for old symlinks..."
remove_old_symlink ".zshrc"
remove_old_symlink ".zshenv"
remove_old_symlink ".aliases"
remove_old_symlink ".tmux.conf"
remove_old_symlink ".gitconfig"
remove_old_symlink ".gitignore"
remove_old_symlink ".zsh"
remove_old_symlink ".vim"
remove_old_symlink ".vimrc"

echo "==> Backing up conflicting configs..."
backup_if_conflict ".config/ghostty"
backup_if_conflict ".config/herdr"

echo "==> Linking shared AI workflow assets..."
link_if_needed "plugins/kalavero/commands" ".claude/commands"
link_if_needed "plugins/kalavero/skills" ".claude/skills"
link_if_needed "plugins/kalavero/agents" ".claude/agents"

link_if_needed "plugins/kalavero/commands" ".agents/commands"
link_if_needed "plugins/kalavero/skills" ".agents/skills"
link_if_needed "plugins/kalavero/agents" ".agents/agents"

link_if_needed "plugins/kalavero/commands" ".config/opencode/commands"
link_if_needed "plugins/kalavero/skills" ".config/opencode/skills"
link_if_needed "plugins/kalavero/agents" ".config/opencode/agents"

link_if_needed "plugins/kalavero/commands" ".pi/agent/prompts"
link_if_needed "plugins/kalavero/skills" ".pi/agent/skills"

link_if_needed "home/AGENTS.md" ".claude/CLAUDE.md"
link_if_needed "home/AGENTS.md" ".config/opencode/AGENTS.md"
link_if_needed "home/AGENTS.md" ".codex/AGENTS.md"
link_if_needed "home/AGENTS.md" ".pi/agent/AGENTS.md"
link_if_needed "plugins/kalavero/commands" ".codex/commands"
link_if_needed "plugins/kalavero/skills" ".codex/skills"
link_if_needed "plugins/kalavero/agents" ".codex/agents"

packages=(home zsh aliases starship git neovim tmux bin ghostty herdr)
echo "==> Stowing packages..."
for pkg in "${packages[@]}"; do
  if [ -d "$DOTFILES_DIR/$pkg" ]; then
    echo "  Stowing $pkg..."
    stow -v -d "$DOTFILES_DIR" -t "$HOME" "$pkg"
  fi
done
