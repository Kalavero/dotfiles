setopt promptsubst

# Load completion functions
fpath=(~/.zsh/completion /opt/homebrew/share/zsh/site-functions /usr/local/share/zsh/site-functions $fpath)

# Completion
autoload -U compinit
compinit -u

# Load custom executable functions
for function in ~/.zsh/functions/*; do
  source $function
done

# Colors
autoload -U colors
colors
export CLICOLOR=1

# History
setopt hist_ignore_all_dups inc_append_history
HISTFILE=~/.zhistory
HISTSIZE=4096
SAVEHIST=4096

# Directory navigation
setopt autocd autopushd pushdminus pushdsilent pushdtohome cdablevars
DIRSTACKSIZE=5

# Extended globbing
setopt extendedglob

# Allow [ or ] wherever you want
unsetopt nomatch

# Vi mode
bindkey -v
bindkey "^F" vi-cmd-mode
bindkey jj vi-cmd-mode

# Keybindings
bindkey "^A" beginning-of-line
bindkey "^E" end-of-line
bindkey "^K" kill-line
bindkey "^R" history-incremental-search-backward
bindkey "^P" history-search-backward
bindkey "^Y" accept-and-hold
bindkey "^N" insert-last-word
bindkey -s "^T" "^[Isudo ^[A" # "t" for "toughguy"

set -o nobeep

# Aliases
[[ -f ~/.aliases ]] && source ~/.aliases

# Zsh syntax highlighting (Homebrew)
if [ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [ -f ~/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source ~/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Local config
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# Secrets
[[ -f ~/.secrets ]] && source ~/.secrets

setopt interactivecomments

# RVM
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"
export PATH="$PATH:$HOME/.rvm/bin"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Starship prompt (must be last)
eval "$(starship init zsh)"
