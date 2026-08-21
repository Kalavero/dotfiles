#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DOTFILES_DIR"

echo "==> Kalavero Dotfiles Installer"
echo ""

RVM_INSTALLER_FILE=""

cleanup_rvm_installer() {
  if [ -n "$RVM_INSTALLER_FILE" ]; then
    rm -f -- "$RVM_INSTALLER_FILE" "$RVM_INSTALLER_FILE.asc"
  fi
}

trap cleanup_rvm_installer EXIT

load_homebrew_environment() {
  local brew_executable

  if command -v brew &>/dev/null; then
    return 0
  fi

  for brew_executable in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$brew_executable" ]; then
      eval "$($brew_executable shellenv)"
      return 0
    fi
  done

  echo "Homebrew was installed but its executable could not be found." >&2
  return 1
}

# 1. Install Homebrew if needed
if ! command -v brew &>/dev/null; then
  echo "==> Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  load_homebrew_environment
fi

# 2. Install packages from Brewfile
echo "==> Installing Homebrew packages..."
brew bundle --file="$DOTFILES_DIR/Brewfile"

# 3. Install RVM and the default Ruby
install_rvm_and_ruby() {
  local rvm_script="$HOME/.rvm/scripts/rvm"
  local rvm_signing_keys=(
    409B6B1796C275462A1703113804BB82D39DC0E3
    7D2BAF1CF37B13E2069D6956105BD0E739499BDB
  )

  if [ ! -s "$rvm_script" ]; then
    echo "==> Installing RVM..."
    gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys "${rvm_signing_keys[@]}"

    RVM_INSTALLER_FILE="$(mktemp "${TMPDIR:-/tmp}/kalavero-rvm-installer.XXXXXX")"
    curl -fsSL https://raw.githubusercontent.com/rvm/rvm/stable/binscripts/rvm-installer \
      -o "$RVM_INSTALLER_FILE"
    curl -fsSL https://raw.githubusercontent.com/rvm/rvm/stable/binscripts/rvm-installer.asc \
      -o "$RVM_INSTALLER_FILE.asc"
    gpg --batch --verify "$RVM_INSTALLER_FILE.asc" "$RVM_INSTALLER_FILE"
    rvm_ignore_dotfiles=yes bash "$RVM_INSTALLER_FILE" stable
  fi

  if [ ! -s "$rvm_script" ]; then
    echo "RVM was installed but $rvm_script could not be found." >&2
    return 1
  fi

  # RVM's shell functions are not compatible with Bash nounset.
  set +u
  # shellcheck source=/dev/null
  source "$rvm_script"
  if rvm use default; then
    echo "==> Using the existing default RVM Ruby."
  else
    echo "==> Installing the default Ruby with RVM..."
    rvm use --default --install ruby
  fi
  set -u
}

install_rvm_and_ruby

# 4. Install Ruby quality tools
install_ruby_quality_tools() {
  local gem_name
  local missing_gems=()
  local quality_gems=(
    rubocop
    rubocop-rails
    rubocop-rspec
    rubocop-performance
    brakeman
    reek
    packwerk
  )

  if ! command -v gem >/dev/null 2>&1; then
    echo "RubyGems was not found after activating the default RVM Ruby." >&2
    return 1
  fi

  for gem_name in "${quality_gems[@]}"; do
    if ! gem list --installed --exact "$gem_name" >/dev/null 2>&1; then
      missing_gems+=("$gem_name")
    fi
  done

  if [ "${#missing_gems[@]}" -eq 0 ]; then
    return 0
  fi

  echo "==> Installing Ruby quality tools..."
  gem install --no-document "${missing_gems[@]}"
}

install_ruby_quality_tools

# 5. Install AI coding tools not managed by Homebrew
if ! command -v pi &>/dev/null; then
  echo "==> Installing Pi..."
  npm install -g --ignore-scripts @earendil-works/pi-coding-agent
fi

if ! command -v skills &>/dev/null; then
  echo "==> Installing Skills CLI..."
  npm install -g --ignore-scripts skills
fi

if ! command -v opencode &>/dev/null; then
  echo "==> Installing OpenCode..."
  curl -fsSL https://opencode.ai/install | bash
fi

if ! command -v no-mistakes &>/dev/null; then
  echo "==> Installing no-mistakes..."
  curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh
fi

if command -v no-mistakes &>/dev/null && ! git remote get-url no-mistakes &>/dev/null; then
  echo "==> Initializing the no-mistakes gate for this repo..."
  no-mistakes init
fi

if ! command -v treehouse &>/dev/null; then
  echo "==> Installing treehouse..."
  curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh
fi

if [ ! -d "$HOME/firstmate" ]; then
  echo "==> Cloning firstmate..."
  git clone https://github.com/kunchenguid/firstmate "$HOME/firstmate"
fi

if command -v skills &>/dev/null; then
  echo "==> Installing shared agent skills..."
  skills add kunchenguid/axi -g -y
  skills add kunchenguid/lavish-axi --skill lavish -g -y
  skills add kunchenguid/firstmate --skill stow -g -y
fi

if ! command -v lavish-axi &>/dev/null; then
  echo "==> Installing Lavish..."
  npm install -g --ignore-scripts lavish-axi
fi

if command -v lavish-axi &>/dev/null; then
  echo "==> Configuring Lavish session hooks..."
  lavish-axi setup hooks
fi

# 6. Clone TPM (Tmux Plugin Manager) if needed
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "==> Installing Tmux Plugin Manager..."
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# 7. Create undo directory for Neovim
mkdir -p "$HOME/.config/nvim/undodir"

prompt_terminal_font() {
  local font_choice

  echo "==> Choose your terminal font:" >&2
  PS3="Select 1 or 2: "
  select font_choice in "Hack Nerd Font" "JetBrainsMono Nerd Font"; do
    case "$REPLY" in
      1|2)
        printf '%s\n' "$font_choice"
        return 0
        ;;
      *)
        echo "Please enter 1 or 2." >&2
        ;;
    esac
  done
}

write_ghostty_font_override() {
  local font_family="$1"
  local override="$HOME/.config/ghostty.local"

  mkdir -p "$(dirname "$override")"

  if [ -e "$override" ] && [ ! -L "$override" ]; then
    local backup
    backup="$override.backup.$(date +%Y%m%d%H%M%S)"
    echo "  Backing up existing ~/.config/ghostty.local -> $(basename "$backup")"
    mv "$override" "$backup"
  fi

  cat >"$override" <<EOF
# Machine-specific override written by install.sh
font-family = $font_family
EOF
}

# 8. Choose the terminal font
terminal_font="$(prompt_terminal_font)"

# 9. Publish workflow assets and stow packages
./sync.sh

# 10. Apply machine-specific Ghostty font override
write_ghostty_font_override "$terminal_font"

# 11. Set Zsh as default shell
if [[ "$SHELL" != *"zsh"* ]]; then
  desired_shell="/bin/zsh"
  if [ -x "$desired_shell" ] && grep -Fxq "$desired_shell" /etc/shells; then
    echo "==> Setting Zsh as default shell..."
    chsh -s "$desired_shell"
  else
    echo "==> Skipping default shell change: $desired_shell is not listed in /etc/shells" >&2
    echo "    Add it to /etc/shells, then run: chsh -s $desired_shell" >&2
  fi
fi

echo ""
echo "==> Done! Next steps:"
echo "  1. Open a new terminal to apply changes"
echo "  2. Set iTerm2 font to $terminal_font (Ghostty is configured automatically)"
echo "  3. Start herdr from any project directory (Ctrl-a ? shows bindings)"
echo "  4. Open nvim — plugins will auto-install on first launch"
echo "  5. In tmux, press Ctrl-a + I to install tmux plugins"
