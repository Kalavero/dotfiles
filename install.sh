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

# 3. Clone TPM (Tmux Plugin Manager) if needed
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "==> Installing Tmux Plugin Manager..."
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# 4. Create undo directory for Neovim
mkdir -p "$HOME/.config/nvim/undodir"

# 5. Remove old symlinks that would conflict with stow
remove_old_symlink() {
  if [ -L "$HOME/$1" ]; then
    echo "  Removing old symlink: ~/$1"
    rm "$HOME/$1"
  fi
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

# 6. Stow all packages
packages=(zsh aliases starship git neovim tmux bin)
echo "==> Stowing packages..."
for pkg in "${packages[@]}"; do
  if [ -d "$DOTFILES_DIR/$pkg" ]; then
    echo "  Stowing $pkg..."
    stow -v -d "$DOTFILES_DIR" -t "$HOME" "$pkg"
  fi
done

# 7. Set Zsh as default shell
if [[ "$SHELL" != *"zsh"* ]]; then
  echo "==> Setting Zsh as default shell..."
  chsh -s "$(which zsh)"
fi

echo ""
echo "==> Done! Next steps:"
echo "  1. Open a new terminal to apply changes"
echo "  2. Set iTerm2 font to JetBrainsMono Nerd Font"
echo "  3. Open nvim — plugins will auto-install on first launch"
echo "  4. In tmux, press Ctrl-a + I to install tmux plugins"
