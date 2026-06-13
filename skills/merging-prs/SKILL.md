---
name: merging-prs
description: "Merges GitHub pull requests safely, monitors default-branch CI and deployments, and completes post-deploy verification or cleanup. Use when asked to merge, ship, land, or deploy a PR."
---

# Merging PRs

Use this workflow when the user asks to merge, ship, land, or deploy a GitHub PR.

IMPORTANT: Only merge when the user explicitly asks and the target PR is unambiguous.
The user's instructions for merge strategy, timing, deployment, and cleanup take precedence
over these defaults.

## Workflow

1. Resolve the PR: URL or number, title, base branch, head branch, draft state,
   review state, and whether GitHub currently considers it mergeable.

2. Confirm it is safe to merge.
   - Check PR status checks and required reviews using the GitHub CLI, API, or UI.
   - Stop for failed checks, draft PRs, unresolved requested changes, merge conflicts,
     or other blockers unless the user explicitly chooses to proceed after seeing the risk.
   - Do not rely on auto-merge unless the repository supports it and the user wants the
     PR queued for later merge. If branch protection, required checks, merge queue, or
     ruleset behavior is unclear, inspect the repo policy or ask.

3. Merge according to the repository's policy.
   - Use the user's requested merge strategy when provided; otherwise infer it from
     repository settings or recent merged PRs.
   - Treat auto-merge or merge queue as timing/scheduling, not as the merge strategy.
   - Delete the source branch only when requested or customary for the repository.
   - Record the PR URL and resulting base-branch commit or merge status.

4. Monitor the base/default branch after the merge.
   - Watch CI or checks triggered by the merged commit. If the repository has no
     post-merge branch CI, say that instead of reporting it as green.
   - If CI fails, gather the failing run links and relevant logs before deciding whether
     to fix forward, revert, or ask the user.

5. Monitor deployment when merging is expected to deploy.
   - Use repository runbooks, workflows, or project instructions to identify the deploy
     path; do not invent deployment commands.
   - Watch automatic deploys to completion. Trigger manual deploys only when the user or
     project instructions authorize that step.

6. Complete post-deploy verification and cleanup.
   - Verify the user-facing, operational, or data outcome that motivated the merge.
   - For destructive cleanup or migrations, dry-run first and proceed only when the
     affected scope is understood and safe or explicitly approved.
   - Clean up local branches or stale state after the merge, CI, deploy, and verification
     status are clear.

## Failure handling

- If pre-merge checks are red, stop before merging and summarize the blocker.
- If the merge command fails, read the error and resolve safe mechanical blockers, such as updating the branch, only when that is consistent with the user's request.
- If default-branch CI or deployment fails after merging, treat it as a live follow-up: gather failing run links and logs, identify the likely cause, and either fix forward in a new PR or ask before reverting.
- Always finish with the PR URL, merge status, default-branch CI status, deploy status if any, verification performed, and any remaining manual follow-up.
