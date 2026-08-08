# Editor
export VISUAL=nvim
export EDITOR=$VISUAL
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="$LANG"

# Path
# Keep Kimi's app-managed CLI as a fallback behind Homebrew-managed commands.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/sbin:$HOME/.kimi-code/bin:$PATH"

# Local config
[[ -f ~/.zshenv.local ]] && source ~/.zshenv.local
