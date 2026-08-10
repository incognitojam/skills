---
name: create-pr
description: Create a GitHub pull request from the current branch
---

Use this workflow when the user asks to create, open, prepare, or submit a PR.

IMPORTANT: The user's custom preferences always take precedence over any default
guidelines or instructions provided below.

Follow these steps to create a PR:

- Run `git diff` to review uncommitted changes
- Commit them. Follow any instructions the user gave you about writing commit messages.
  messages.
- Determine the current branch, upstream branch, and target base branch. Default to the repository's main branch when the user has not specified a base.
- Review the final branch diff against the target base branch before creating the PR. Use the workspace diff tool if available.
- Use `gh pr create [--base <base_branch>]` to create a PR onto the target branch. Keep the title under 80 characters. Keep the description under five sentences, unless the user instructed you otherwise. Describe not just the changes made in this session but ALL changes in the workspace diff.
- Link GitHub issues only when appropriate: `Closes #N` only if the PR fully resolves the issue; otherwise use `Refs #N` or `Part of #N`. Do not add a closing keyword when no issue is fully resolved.

If any of these steps fail, ask the user for help.
