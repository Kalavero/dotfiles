---
name: dotfiles-package
description: >
  Conventions for the kalavero dotfiles repo. Use when adding, moving, or restructuring
  configuration files in this dotfiles repository — new tools, new stow packages, shell config,
  or editor config changes.
---

# Dotfiles Package Conventions

How configuration is organized in this repo so changes land in the right place and survive `stow`.

## The rules

- **Stow packages are registered in `stow-packages.txt`** and their internal structure mirrors `$HOME`. A file destined for `~/.config/foo/bar.toml` lives at `<package>/.config/foo/bar.toml`. Run `stow <package>` from the repo root to symlink it.
- **New tool config goes in an existing package when it belongs to that tool's domain** (a zsh function → `zsh/`, an alias → `aliases/`); create a new package only for a genuinely new tool with its own config tree. When creating one, add it to `stow-packages.txt` and to the package tables in `README.md` and `CLAUDE.md`.
- **Machine-specific settings use the `.local` pattern**: the stowed file sources a gitignored `.local` counterpart (`.zshrc.local`, `.zshenv.local`, `.aliases.local`, `.gitconfig.local`, `.tmux.conf.local`, `~/.config/ghostty.local`). Anything machine- or job-specific belongs there, never in the repo.
- **Secrets go in `~/.secrets`** (gitignored, sourced by zshrc). Never commit tokens, even temporarily.
- **Nothing employer-specific in the repo** — no company names, team ticket prefixes, or configs that only make sense at one job. That content belongs in `.local` files.
- **Dependencies**: a new CLI tool or font goes in the `Brewfile`; one-time setup steps (cloning TPM, changing the default shell) go in `install.sh`. Don't duplicate between them.

## After structural changes

- Moving or renaming files within a package: `stow -R <package>` to refresh symlinks.
- Removing a package: `stow -D <package>` before deleting the directory, or dead symlinks remain in `$HOME`.
- Verify with `ls -la ~/<target>` that the symlink points into the repo, then open a new shell (or source the file) to confirm the config loads.

## Shared AI workflow development

Shared Claude Code, OpenCode, Pi, and Codex workflow assets live in `plugins/kalavero/`. Claude Code also loads this directory as a plugin through `.claude-plugin/marketplace.json`; `sync.sh` publishes the shared assets to each tool's discovery locations. Commands are single files in `commands/`; skills are directories with a `SKILL.md` in `skills/`; agents live in `agents/`.

After changing a shared workflow asset, run `sync.sh` to publish it and `./script/check --strict` to validate the bundle. Codex discovers shared skills through `~/.agents/skills`; do not publish them to `~/.codex/skills` or vendor host-managed system skills. Vendored third-party content keeps an attribution comment naming the source and license.
