# Editor
export VISUAL=nvim
export EDITOR=$VISUAL
export LC_ALL=$LANG

# Path
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/sbin:$PATH"

# Local config
[[ -f ~/.zshenv.local ]] && source ~/.zshenv.local
