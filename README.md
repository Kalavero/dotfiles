# Kalavero Dotfiles

Personal development environment for macOS, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's Included

| Package | Tool | Config |
|---------|------|--------|
| `zsh/` | Zsh + [Starship](https://starship.rs) prompt | Vi mode, history, autocd, syntax highlighting |
| `aliases/` | Shell aliases | Git, Docker, Ruby/Rails, file navigation |
| `neovim/` | Neovim (Lua) | [lazy.nvim](https://github.com/folke/lazy.nvim), Gruvbox, Telescope, LSP, Treesitter |
| `tmux/` | Tmux | Ctrl-a prefix, vim-aware navigation, TPM |
| `git/` | Git | 60+ aliases, nvimdiff mergetool |
| `starship/` | Starship prompt | Git branch/status, Ruby/Node versions |
| `bin/` | Scripts | `tat` — tmux attach-or-create |

## Install

```bash
git clone https://github.com/andrelucasvsouza/kalavero_dotfiles.git ~/kalavero_dotfiles
cd ~/kalavero_dotfiles
./install.sh
```

The install script will:
1. Install [Homebrew](https://brew.sh) if needed
2. Install all dependencies from the `Brewfile`
3. Clone [TPM](https://github.com/tmux-plugins/tpm) for tmux plugins
4. Stow all packages (symlink configs to `$HOME`)
5. Set Zsh as the default shell

After install, open Neovim — plugins will auto-install on first launch.
In tmux, press `Ctrl-a I` to install tmux plugins.

### Stow a Single Package

```bash
stow neovim    # symlink just neovim config
stow -D tmux   # remove tmux symlinks
```

## Key Mappings

Leader key: **Space**

### Neovim

| Key | Action |
|-----|--------|
| `<Leader>t` | Find files (Telescope) |
| `<Leader>b` | Buffers |
| `<Leader>m` | Recent files |
| `K` | Grep word under cursor |
| `<C-\>` | Toggle file tree |
| `<Leader><Leader>` | Switch last two files |
| `vv` / `ss` | Vertical / horizontal split |
| `<Leader>-` / `<Leader>=` | Zoom pane / rebalance |
| `//` | Clear search highlight |
| `<Leader>gs` | Git status |
| `<Leader>y` | Yank to clipboard |
| `<Leader>p` | Paste from clipboard |

#### RSpec (via tmux runner)

| Key | Action |
|-----|--------|
| `<Leader>rs` | Run current spec |
| `<Leader>rn` | Run nearest spec |
| `<Leader>rl` | Run last spec |
| `<Leader>ra` | Run all specs |
| `<Leader>ru` | Rubocop (directory) |
| `<Leader>rfu` | Rubocop (current file) |

#### LSP

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gr` | References |
| `gi` | Implementation |
| `gh` | Hover |
| `<Leader>lr` | Rename |
| `<Leader>la` | Code action |
| `<Leader>lf` | Format |
| `[d` / `]d` | Prev / next diagnostic |

### Tmux

Prefix: **Ctrl-a**

| Key | Action |
|-----|--------|
| `v` / `s` | Vertical / horizontal split |
| `Ctrl-h/j/k/l` | Navigate panes (vim-aware) |
| `Ctrl-z` | Zoom pane |
| `c` | New window |
| `e` / `E` | Sync panes on / off |
| `r` | Reload config |
| `Shift-arrows` | Resize pane (small) |
| `Ctrl-arrows` | Resize pane (large) |

### Common Aliases

| Alias | Command |
|-------|---------|
| `gs` | `git status` |
| `gco` | `git checkout` |
| `gnb` | `git checkout -b` |
| `gpl` / `gp` | `git pull` / `git push` |
| `gpsh` | Push current branch |
| `gd` / `gdc` | Diff / diff cached |
| `gl` | Git log (graph) |
| `dc` | `docker-compose` |
| `dcr` | `docker-compose run --rm --service-ports` |
| `rs` | `rspec spec` |
| `rc` | `rails c` |
| `vim` | `nvim` |

## Customization

Override any config locally without touching tracked files:

| File | Purpose |
|------|---------|
| `~/.aliases.local` | Extra aliases |
| `~/.zshrc.local` | Extra shell config |
| `~/.zshenv.local` | Extra env vars |
| `~/.gitconfig.local` | Git user, signing, etc. |
| `~/.tmux.conf.local` | Extra tmux config |
| `~/.secrets` | API keys, tokens |

## Testing with Docker

```bash
docker build -t kalavero-dotfiles .
docker run -it kalavero-dotfiles
```

## Credits

Inspired by [Campus Code dotfiles](https://github.com/campuscode/cc_dotfiles), [Skwp](https://github.com/skwp/dotfiles), and [ThoughtBot](https://github.com/thoughtbot/dotfiles).
