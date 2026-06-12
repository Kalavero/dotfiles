---
description: Generate release notes from merged PRs — grouped by type, with PR and ticket links
---

`$ARGUMENTS` is optional: a tag, range (`v1.2.0..HEAD`), or date to start from (default: the last tag, or the last 30 days if the repo has no tags).

### 1. Collect the changes

- Resolve the range: `git describe --tags --abbrev=0` for the last tag; fall back to a date window.
- List merged PRs in the range: `gh pr list --state merged --base <default-branch> --search "merged:><date>"`, cross-checked against `git log <range> --merges --oneline` (or first-parent log for squash-merge repos).
- Note any commits landed without a PR; include them under their own heading if significant.

### 2. Group and write

Classify each PR from its title, labels, and (when ambiguous) body — feature, fix, or maintenance. Follow the format of existing release notes if the repo has a CHANGELOG or GitHub releases; otherwise:

```markdown
## <version or date>

### Features
- <user-facing description> (#PR, <ticket if linked>)

### Fixes
- <what was broken, now fixed> (#PR)

### Maintenance
- <dependency bumps, refactors, CI — one line each, or summarized>
```

Write for the reader of the release, not the author of the commit: lead with the user-visible effect, not the implementation. Pull ticket links from PR bodies; fetch titles via the tracker MCP when connected.

### 3. Deliver

Output the section ready to paste. If the repo has a `CHANGELOG.md`, offer to prepend it; if it uses GitHub releases, offer `gh release create --notes-file -` as a draft. Don't publish anything without confirmation.
