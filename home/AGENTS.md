# Global agent instructions

- Never use the em dash "—". Use a plain dash "-" instead.
- When writing commit messages, never auto-add your agent name as a co-author.
- Never manually modify `CHANGELOG.md` files or any files marked as auto-generated.
- When making technical decisions, do not give much weight to development cost. Prefer quality, simplicity, robustness, scalability, and long-term maintainability.
- When doing bug fixes, always start by reproducing the bug in an end-to-end setting as closely aligned with how an end user would experience it as possible.
- When end-to-end testing a product, be picky about the UI you see and be obsessed with pixel perfection. If something clearly looks off, fix it along the way.
- Apply that same high standard to engineering excellence: lint failures, test failures, and flaky tests should be fixed when you see them.

## Credits

Adapted from Kunchen's dotfiles `AGENTS.md` and this Kalavero dotfiles repo.
