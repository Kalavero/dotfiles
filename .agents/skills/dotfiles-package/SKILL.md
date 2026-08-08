---
name: dotfiles-package
description: >
  Conventions for this dotfiles repository. Use when adding, moving, or restructuring
  configuration files here - new tools, new Stow packages, shell config, or editor config changes.
---

# Dotfiles Package Conventions

## The rules

- Register Stow packages in `stow-packages.txt` and mirror `$HOME` within them. A file for `~/.config/foo/bar.toml` lives at `<package>/.config/foo/bar.toml`. Run `stow <package>` from the repository root to symlink it.
- Put new tool configuration in the existing package for that tool's domain. Create a package only for a genuinely new tool with its own config tree. Add a new package to `stow-packages.txt` and the package table in `README.md`.
- Put machine-specific settings in gitignored `.local` files: `.zshrc.local`, `.zshenv.local`, `.aliases.local`, `.gitconfig.local`, `.tmux.conf.local`, or `~/.config/ghostty.local`.
- Put secrets in `~/.secrets`. Never commit tokens, even temporarily.
- Keep employer-specific configuration out of the repository. Put it in a `.local` file.
- Add new CLI tools, fonts, and GUI apps (Homebrew casks) to `Brewfile`; put one-time setup in `install.sh`. GUI apps configured through their own preferences do not need a Stow package.

## Structural changes

- Run `stow -R <package>` after moving or renaming files in a package.
- Run `stow -D <package>` before removing a package.
- Confirm symlinks point into the repository and load the changed shell configuration in a new shell or by sourcing it.
