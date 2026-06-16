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
| `ghostty/` | [Ghostty](https://ghostty.org) terminal | Gruvbox Dark, JetBrainsMono Nerd Font 14, option-as-alt |
| `plugins/` | [Claude Code](https://claude.com/claude-code) plugin | Commands, skills, and agents for AI-assisted development (see [AI Workflow](#ai-workflow-claude-code)) |

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
| `<C-\>` | Toggle file tree at current file |
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

## AI Workflow (Claude Code)

The repo doubles as a [Claude Code](https://claude.com/claude-code) plugin marketplace. The `kalavero` plugin at `plugins/kalavero/` packages personal engineering workflows as commands, skills, and agents. Nothing in it is tied to a specific employer or vendor — trackers, PR templates, and branch conventions are discovered at runtime from whatever repo and MCP servers are available.

### Setup

```bash
claude plugin marketplace add ~/kalavero_dotfiles
claude plugin install kalavero@kalavero
```

### Commands

Commands are typed explicitly (`/kalavero:<name>`) to kick off a workflow:

| Command | What it does |
|---------|--------------|
| `/kalavero:implement` | Implement a task end-to-end with the agent team (see below) |
| `/kalavero:fix-bug` | Fix a bug: analyze the ticket, trace root cause, failing test first, reviewed fix |
| `/kalavero:start-ticket` | Fetch a ticket, summarize it, move to In Progress, create a branch |
| `/kalavero:pr-create` | Draft a PR using the repo's template and ticket-linking conventions |
| `/kalavero:plan` | Break work into small verifiable tasks with acceptance criteria |
| `/kalavero:build` | Implement the next planned task — test, verify, commit |
| `/kalavero:why` | Explain why code exists by tracing commits, PRs, and tickets |
| `/kalavero:standup` | Summarize recent commits, PRs, and ticket movement into standup notes |
| `/kalavero:release-notes` | Generate a changelog from merged PRs since the last release |

### Skills

Skills are picked up by Claude automatically when a task matches their description (no command needed):

| Skill | Kicks in when... |
|-------|------------------|
| `tad` | Writing a technical approach document before coding |
| `tad-to-tickets` | An approved TAD needs to become tracker tickets |
| `agent-brief` | Delegating work to an AI coding agent from a rough idea |
| `refactor-plan` | Restructuring code where changing behavior is the main risk |
| `migration-safety` | Writing or reviewing database migrations |
| `flaky-spec` | A test fails intermittently or only in CI |
| `dotfiles-package` | Adding or restructuring config in this repo |
| `planning-and-task-breakdown`, `incremental-implementation`, `test-driven-development`, `debugging-and-error-recovery` | Core engineering methodology (vendored, see Credits) |

### Agents

Agents are specialized subagent personas, launched individually or coordinated by `/kalavero:implement`:

| Agent | Role |
|-------|------|
| `researcher` | Read-only: maps the code relevant to a task — files, patterns, prior art, risks |
| `planner` | Read-only: decomposes work into small ordered tasks with acceptance criteria |
| `implementer` | Executes exactly one task — failing test first, minimal code, honest report |
| `test-engineer` | Test strategy, coverage analysis, and test writing in the project's idiom |
| `code-reviewer` | Five-axis review (correctness, readability, architecture, security, performance) with an APPROVE / REQUEST CHANGES verdict |

`/kalavero:implement` wires them together: researcher maps the code, planner produces a task list (gated on human approval), then for each task the implementer builds while test-engineer and code-reviewer verify in parallel — failed reviews loop back to the implementer, capped at two rounds before escalating to you.

## Testing with Docker

```bash
docker build -t kalavero-dotfiles .
docker run -it kalavero-dotfiles
```

## Credits

Inspired by [Campus Code dotfiles](https://github.com/campuscode/cc_dotfiles), [Skwp](https://github.com/skwp/dotfiles), and [ThoughtBot](https://github.com/thoughtbot/dotfiles).

Parts of the Claude Code plugin (the `build`/`plan` commands, the core methodology skills, and the `code-reviewer`/`test-engineer` agents) are adapted from [Addy Osmani's agent-skills](https://github.com/addyosmani/agent-skills) (MIT License), with attribution comments in each file.
