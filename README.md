# Kalavero Dotfiles

Personal development environment for macOS, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's Included

| Package | Tool | Config |
|---------|------|--------|
| `home/` | Shared agent instructions | Global `~/AGENTS.md` used by supported AI tools |
| `zsh/` | Zsh + [Starship](https://starship.rs) prompt | Vi mode, history, autocd, syntax highlighting |
| `aliases/` | Shell aliases | Git, Docker, Ruby/Rails, file navigation |
| `neovim/` | Neovim (Lua) | [lazy.nvim](https://github.com/folke/lazy.nvim), Gruvbox, Telescope, LSP, Treesitter |
| `tmux/` | Tmux | Ctrl-a prefix, vim-aware navigation, TPM |
| `git/` | Git | 60+ aliases, nvimdiff mergetool |
| `starship/` | Starship prompt | Git branch/status, Ruby/Node versions |
| `bin/` | Scripts | `tat` — tmux attach-or-create |
| `ghostty/` | [Ghostty](https://ghostty.org) terminal | Rose Pine Moon, Hack Nerd Font 14, option-as-alt, 0.8 opacity, blur 50 |
| `herdr/` | [Herdr](https://herdr.dev) agent multiplexer | Ctrl-a prefix, tmux-like pane/tab bindings |
| `plugins/` | [Claude Code](https://claude.com/claude-code) plugin | Commands, skills, and agents for AI-assisted development (see [AI Workflow](#ai-workflow-claude-code)) |

> `iterm2/` is not a stow package — it holds manual setup notes ([`iterm2/README.md`](iterm2/README.md)) for the alternative terminal, which is configured through its GUI rather than a dotfile.

## Install

```bash
git clone https://github.com/andrelucasvsouza/kalavero_dotfiles.git ~/kalavero_dotfiles
cd ~/kalavero_dotfiles
./install.sh
```

The install script will:
1. Install [Homebrew](https://brew.sh) if needed
2. Install all dependencies from the `Brewfile`, including Node.js
3. Install [Pi](https://pi.dev/) and [OpenCode](https://opencode.ai/)
4. Clone [TPM](https://github.com/tmux-plugins/tpm) for tmux plugins
5. Publish the shared Claude/OpenCode/Pi/Codex workflow assets and the global agent instructions file into the tool-specific locations they scan
6. Symlink a global `~/AGENTS.md` instructions file and stow all packages (symlink configs to `$HOME`)
7. Set Zsh as the default shell

### Sync Changes

```bash
./sync.sh
```

Reapplies tracked symlinks and stows packages without reinstalling dependencies. It also defaults subagents to lower-cost models: Haiku in Claude Code and GPT-5.6 Terra in OpenCode and Codex. Existing explicit harness overrides are preserved. Pi has no built-in subagents, so no Pi model override is generated.

Use `./sync.sh --dry-run` to preview changes. For isolated verification, `./sync.sh --target-home /absolute/path` publishes into an existing temporary home instead of your real home directory. The packages to stow are defined once in `stow-packages.txt`.

The installer will also prompt you to pick either Hack Nerd Font or JetBrainsMono Nerd Font and apply that choice to Ghostty.
It installs Herdr and stows `~/.config/herdr/config.toml` with tmux-style keybindings.

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

#### RSpec and checks (via tmux or Herdr runner)

| Key | Action |
|-----|--------|
| `<Leader>rs` | Run current spec |
| `<Leader>rn` | Run nearest spec |
| `<Leader>rl` | Run last spec |
| `<Leader>ra` | Run all specs |
| `<Leader>ru` | Rubocop (directory) |
| `<Leader>rfu` | Rubocop (current file) |

Use `:VtrAttachToPane` to choose where these commands run. In a Herdr tab with
two panes, it automatically attaches to the other pane. With more panes it
opens a picker, and an explicit ID such as `:VtrAttachToPane wA:p4` also works.
Tmux continues to use `vim-tmux-runner` and its numeric pane IDs.

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
| `~/.config/ghostty.local` | Machine-specific Ghostty settings |
| `~/.secrets` | API keys, tokens |

## AI Workflow

The repo doubles as a [Claude Code](https://claude.com/claude-code) plugin marketplace. The `kalavero` plugin at `plugins/kalavero/` packages personal engineering workflows as commands, skills, and agents. Nothing in it is tied to a specific employer or vendor — trackers, PR templates, and branch conventions are discovered at runtime from whatever repo and MCP servers are available.

The same source assets are published by `sync.sh` for Claude Code, OpenCode, Pi, and Codex. Claude and OpenCode agent files are generated because their frontmatter formats differ; generated files contain an ownership marker and should not be edited directly.

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
| `/kalavero:green` | Drive the test suite to green — run, diagnose, fix, re-run until passing |
| `/kalavero:ci-watch` | Watch the branch's CI run and fix failures until it goes green |
| `/kalavero:babysit-prs` | Check open PRs for blockers (CI, reviews, conflicts, ready-to-merge); loopable |
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
| `skill-creator` | Creating, testing, and refining new skills |
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

Run the repository checks before syncing changes into your real home:

```bash
./script/check
```

The check command validates shell syntax, package and documentation consistency, plugin metadata, agent generation, Codex configuration updates, and a full sync against a temporary home. Install the Python strict-check dependency with `python3 -m venv .venv && .venv/bin/python3 -m pip install -r requirements-dev.txt`; the check script detects that virtual environment automatically. CI runs `./script/check --strict`.

The Docker image provides a separate Linux Stow smoke test using the same `stow-packages.txt` registry:

```bash
docker build -t kalavero-dotfiles .
docker run -it kalavero-dotfiles
```

### Workflow asset maintenance

- Update vendored `.system` skill directories as complete upstream units, including their license and attribution files.
- Run `./script/check --strict` after changing commands, agents, skills, manifests, or generated-output rules.
- Advance the plugin manifest version only as part of an explicit plugin release.
- Treat `CHANGELOG.md` as release-owned documentation, not a file for routine configuration changes.

## Credits

Inspired by [Campus Code dotfiles](https://github.com/campuscode/cc_dotfiles), [Skwp](https://github.com/skwp/dotfiles), and [ThoughtBot](https://github.com/thoughtbot/dotfiles).

Parts of the Claude Code plugin (the `build`/`plan` commands, the core methodology skills, and the `code-reviewer`/`test-engineer` agents) are adapted from [Addy Osmani's agent-skills](https://github.com/addyosmani/agent-skills) (MIT License), with attribution comments in each file.
