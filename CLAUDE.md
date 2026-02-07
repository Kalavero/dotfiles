# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal dotfiles for macOS development. Uses **GNU Stow** for symlink management — each top-level directory is a stow package whose internal structure mirrors `$HOME`.

## Architecture

**Stow packages:** Run `stow <package>` from the repo root to symlink a package into `$HOME`. For example, `stow neovim` creates `~/.config/nvim/ -> kalavero_dotfiles/neovim/.config/nvim/`.

**Local override pattern:** Most configs source a `.local` counterpart for machine-specific settings (`.aliases.local`, `.zshrc.local`, `.zshenv.local`, `.gitconfig.local`, `.tmux.conf.local`). Secrets go in `~/.secrets` (gitignored).

## Stow Packages

| Package | What it configures |
|---------|--------------------|
| `zsh/` | `.zshrc`, `.zshenv`, `.zsh/` (functions, completions) |
| `aliases/` | `.aliases` (git, docker, ruby/rails, file nav, macOS) |
| `starship/` | `.config/starship.toml` (prompt theme) |
| `git/` | `.gitconfig` (60+ aliases, nvimdiff mergetool), `.gitignore_global` |
| `neovim/` | `.config/nvim/` (Lua config, lazy.nvim plugins) |
| `tmux/` | `.tmux.conf` (prefix Ctrl-a, vim-aware nav, TPM) |
| `bin/` | `.local/bin/tat` (tmux attach-or-create) |

## Neovim Config Structure

```
neovim/.config/nvim/
├── init.lua                    # Entry point
└── lua/
    ├── config/
    │   ├── options.lua         # Editor settings (leader=Space, tabs=2, etc.)
    │   ├── keymaps.lua         # All key mappings (migrated from Vim)
    │   ├── autocmds.lua        # Autocommands (filetype, spell, etc.)
    │   └── lazy.lua            # lazy.nvim bootstrap
    └── plugins/                # Each file returns a lazy.nvim plugin spec
```

Key plugin migrations: CtrlP -> telescope, NERDTree -> nvim-tree, Syntastic -> nvim-lint, CoC -> mason+lspconfig+nvim-cmp, airline -> lualine, tComment -> Comment.nvim, vim-surround -> nvim-surround. LSP servers: ts_ls, eslint, ruby_lsp, lua_ls.

## Install & Build

```bash
./install.sh        # Installs Homebrew deps (Brewfile), clones TPM, stows all packages, sets zsh as default shell
brew bundle         # Just the Homebrew packages
stow <package>      # Stow a single package
stow -D <package>   # Unstow (remove symlinks)
```

## Tech Stack

Zsh + Starship prompt, Neovim (Lua), Tmux + TPM, Git. Ruby (rvm) + Node.js (nvm). Dev tools: RSpec, Rubocop, ESLint, Prettier.
