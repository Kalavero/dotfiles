# Changelog

All notable changes to these dotfiles are documented here.

## 2026-06-17

### Added

- **Three plugin loop commands** — `/kalavero:green` (drive the test suite to
  green), `/kalavero:ci-watch` (watch the branch's CI run and fix failures until
  it passes), and `/kalavero:babysit-prs` (check open PRs for CI failures,
  review comments, conflicts, or merge readiness).

## 2026-06-15

### Added

- **Claude Code plugin (`kalavero`)** — the repo now doubles as a plugin
  marketplace providing AI-assisted development workflows. Install with
  `claude plugin marketplace add ~/kalavero_dotfiles && claude plugin install kalavero@kalavero`.
  See the AI Workflow section of the README.
  - **Commands**: `/kalavero:implement` (drive the agent team end-to-end),
    `/kalavero:fix-bug`, `/kalavero:start-ticket`, `/kalavero:pr-create`,
    `/kalavero:plan`, `/kalavero:build`, `/kalavero:why`, `/kalavero:standup`,
    `/kalavero:release-notes`.
  - **Skills** (auto-applied when a task matches): `tad`, `tad-to-tickets`,
    `agent-brief`, `refactor-plan`, `migration-safety`, `flaky-spec`,
    plus vendored core methodology (`planning-and-task-breakdown`,
    `incremental-implementation`, `debugging-and-error-recovery`).
  - **Agents**: `researcher`, `planner`, `implementer`, `test-engineer`, and
    `code-reviewer`, coordinated by `/kalavero:implement` (research → plan →
    build/test/review loop with human approval gates).
- **Ghostty terminal stow package** — Rose Pine Moon, Hack Nerd Font 14, 0.8 opacity, blur 50,
  option-as-alt, and clipboard access matching the iTerm2 setup, with an optional
  gitignored `config.local` for machine-local overrides (#1).
- **bun** added to the zsh `PATH` with completions.

### Fixed

- **Fresh-machine install no longer aborts on a pre-existing Ghostty config.**
  A real `~/.config/ghostty/config` previously made `stow` fail and, under
  `set -euo pipefail`, killed `install.sh` mid-run. The installer now moves a
  conflicting real config aside to a timestamped backup before stowing.

### Changed

- The `tad` skill is now tracker- and docs-tool-agnostic (no vendor named as a
  requirement); integrations are discovered at runtime.
- Documented the AI workflow and the non-stowed `iterm2/` package (manual GUI
  setup) in the README and `CLAUDE.md`.
- `tasks/` is gitignored (scratch space for plans and todos).
