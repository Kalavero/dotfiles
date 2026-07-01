# AGENTS.md

This repository is a personal macOS dotfiles setup managed with GNU Stow.

## How The Repo Is Organized

- Each top-level directory is a stow package.
- Package contents mirror paths under `$HOME`.
- `iterm2/` is documentation only and is not stowed.

## Common Commands

- `./install.sh` installs dependencies, stows packages, and sets up the shell.
- `stow <package>` stows a single package.
- `stow -D <package>` unstows a package.
- `brew bundle` installs Homebrew dependencies.

## Local Overrides

- Prefer `.local` files for machine-specific config.
- Keep secrets in `~/.secrets`.
- Do not hardcode machine-specific values into tracked files unless required.

## Working Rules

- Keep changes minimal and aligned with the existing style.
- Prefer the current patterns in the repo over introducing new abstractions.
- Do not revert or overwrite user changes unless explicitly asked.
- Avoid destructive git operations unless explicitly requested.

## What To Check Before Editing

- Read the relevant package files and existing docs first.
- Verify whether a setting already has a `.local` override path.
- Check for installer or stow side effects before changing layout.

## Verification

- Prefer the smallest practical verification step for the change.
- For dotfile changes, confirm the affected package still stows cleanly.
- For shell or install changes, sanity-check the relevant command or script.

## Shared AI Workflow

- The `plugins/kalavero/` package is the source of truth for the repo's Claude/OpenCode/Pi workflow assets.
- `install.sh` publishes those assets into the user locations each tool scans: Claude Code (`~/.claude`), OpenCode (`~/.agents` and `~/.config/opencode`), Pi (`~/.pi/agent`), and Codex (`~/.codex` plus this repo's `AGENTS.md`).
- When editing a command, agent, or skill, keep the plugin package and the published locations aligned.
