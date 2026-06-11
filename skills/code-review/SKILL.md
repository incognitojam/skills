---
name: code-review
description: "Checklist for reviewing a PR, diff, or commit for hygiene and correctness. Use when asked to review changes, a pull request, or a diff for atomicity, dead code, scoped commits, single-source-of-truth, or dependency changes."
---

# Code Review

Apply this checklist when reviewing a PR, diff, or commit. Report concrete
findings with file/line references; don't restate the whole diff.

## Checklist

- Flag code added without a caller, or an interface whose usage isn't in the diff.
- Flag mechanical changes (renames, formatting) mixed into behavioral diffs.
- Check the PR is atomic and self-justifying; call out scaffolding that adds no usable feature yet.
- Apply the commit why-rule: flag a stated why that cites no checkable artifact, and flag a closing keyword (`Closes #N`) on a change that only partially addresses the referenced issue.
- Check commit/PR titles follow Scoped Commits (`<scope>: <description>`) with a scope already in use in the repo's history.
- Single source of truth for values: flag the same constant, config value, or type defined in more than one place.
- Single source of truth for docs: flag comments or docs that restate what the code/types/schema already express.
- When a PR adds or bumps a dependency, or uses a library API you're not certain is current, check the library's docs/changelog for breaking changes.
- Flag code comments, commit messages, or descriptions that contradict each other or the implementation.
