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

- **Every top-level directory is a GNU Stow package** whose internal structure mirrors `$HOME`. A file destined for `~/.config/foo/bar.toml` lives at `<package>/.config/foo/bar.toml`. Run `stow <package>` from the repo root to symlink it.
- **New tool config goes in an existing package when it belongs to that tool's domain** (a zsh function → `zsh/`, an alias → `aliases/`); create a new package only for a genuinely new tool with its own config tree. When creating one, add it to the package table in `CLAUDE.md` and to the stow loop in `install.sh`.
- **Machine-specific settings use the `.local` pattern**: the stowed file sources a gitignored `.local` counterpart (`.zshrc.local`, `.aliases.local`, `.gitconfig.local`, `.tmux.conf.local`). Anything machine- or job-specific belongs there, never in the repo.
- **Secrets go in `~/.secrets`** (gitignored, sourced by zshrc). Never commit tokens, even temporarily.
- **Nothing employer-specific in the repo** — no company names, team ticket prefixes, or configs that only make sense at one job. That content belongs in `.local` files.
- **Dependencies**: a new CLI tool or font goes in the `Brewfile`; one-time setup steps (cloning TPM, changing the default shell) go in `install.sh`. Don't duplicate between them.

## After structural changes

- Moving or renaming files within a package: `stow -R <package>` to refresh symlinks.
- Removing a package: `stow -D <package>` before deleting the directory, or dead symlinks remain in `$HOME`.
- Verify with `ls -la ~/<target>` that the symlink points into the repo, then open a new shell (or source the file) to confirm the config loads.

## Plugin development

Claude Code customizations live in `plugins/kalavero/` (not stowed — loaded via the plugin marketplace at `.claude-plugin/marketplace.json`). Commands are single files in `commands/`; skills are directories with a `SKILL.md` in `skills/`. Vendored third-party content keeps an attribution comment naming the source and license.
