#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DOTFILES_DIR"

echo "==> Kalavero Dotfiles Installer"
echo ""

# 1. Install Homebrew if needed
if ! command -v brew &>/dev/null; then
  echo "==> Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# 2. Install packages from Brewfile
echo "==> Installing Homebrew packages..."
brew bundle --file="$DOTFILES_DIR/Brewfile"

# 3. Install AI coding tools
if ! command -v pi &>/dev/null; then
  echo "==> Installing Pi..."
  npm install -g --ignore-scripts @earendil-works/pi-coding-agent
fi

if ! command -v opencode &>/dev/null; then
  echo "==> Installing OpenCode..."
  curl -fsSL https://opencode.ai/install | bash
fi

# 4. Clone TPM (Tmux Plugin Manager) if needed
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "==> Installing Tmux Plugin Manager..."
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# 5. Create undo directory for Neovim
mkdir -p "$HOME/.config/nvim/undodir"

# 6. Remove old symlinks that would conflict with stow
remove_old_symlink() {
  if [ -L "$HOME/$1" ]; then
    echo "  Removing old symlink: ~/$1"
    rm "$HOME/$1"
  fi
}

# Back up a real config that would make stow abort. Packages that fold a whole
# ~/.config subdirectory (e.g. ghostty) conflict when that directory already
# exists with real files — stow refuses rather than overwrite it.
backup_if_conflict() {
  [ -L "$HOME/$1" ] && return 0       # already a symlink; stow re-stows cleanly
  [ -e "$HOME/$1" ] || return 0       # nothing there; stow will create it
  local backup="$HOME/$1.backup.$(date +%Y%m%d%H%M%S)"
  echo "  Backing up existing ~/$1 -> $(basename "$backup")"
  mv "$HOME/$1" "$backup"
}

prompt_terminal_font() {
  local font_choice

  echo "==> Choose your terminal font:"
  PS3="Select 1 or 2: "
  select font_choice in "Hack Nerd Font" "JetBrainsMono Nerd Font"; do
    case "$REPLY" in
      1|2)
        printf '%s\n' "$font_choice"
        return 0
        ;;
      *)
        echo "Please enter 1 or 2."
        ;;
    esac
  done
}

write_ghostty_font_override() {
  local font_family="$1"
  local override="$HOME/.config/ghostty.local"

  mkdir -p "$(dirname "$override")"

  if [ -e "$override" ] && [ ! -L "$override" ]; then
    local backup="$override.backup.$(date +%Y%m%d%H%M%S)"
    echo "  Backing up existing ~/.config/ghostty.local -> $(basename "$backup")"
    mv "$override" "$backup"
  fi

  cat >"$override" <<EOF
# Machine-specific override written by install.sh
font-family = $font_family
EOF
}

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

terminal_font="$(prompt_terminal_font)"

# 7. Publish shared AI workflow assets
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

link_if_needed "AGENTS.md" ".codex/AGENTS.md"
link_if_needed "plugins/kalavero/commands" ".codex/commands"
link_if_needed "plugins/kalavero/skills" ".codex/skills"
link_if_needed "plugins/kalavero/agents" ".codex/agents"

# 8. Stow all packages
packages=(zsh aliases starship git neovim tmux bin ghostty)
echo "==> Stowing packages..."
for pkg in "${packages[@]}"; do
  if [ -d "$DOTFILES_DIR/$pkg" ]; then
    echo "  Stowing $pkg..."
    stow -v -d "$DOTFILES_DIR" -t "$HOME" "$pkg"
  fi
done

write_ghostty_font_override "$terminal_font"

# 9. Set Zsh as default shell
if [[ "$SHELL" != *"zsh"* ]]; then
  echo "==> Setting Zsh as default shell..."
  chsh -s "$(which zsh)"
fi

echo ""
echo "==> Done! Next steps:"
echo "  1. Open a new terminal to apply changes"
echo "  2. Set iTerm2 font to $terminal_font (Ghostty is configured automatically)"
echo "  3. Open nvim — plugins will auto-install on first launch"
echo "  4. In tmux, press Ctrl-a + I to install tmux plugins"
