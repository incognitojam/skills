---
name: merging-prs
description: "Safely merge or land a GitHub pull request and verify the result. Use only when explicitly asked to merge, land, or ship a PR."
---

# Merging PRs

Only merge when the user explicitly asks and the target PR is unambiguous. Follow, in order:
the user's instructions, repository instructions and runbooks, GitHub rules and settings,
established repository conventions, then these conservative defaults.

## Workflow

1. Resolve the PR URL or number. Confirm its title, base and head branches, draft state,
   review state, checks, and mergeability.

2. Check for blockers.
   - Stop for failed checks, draft PRs, unresolved requested changes, merge conflicts,
     or other blockers unless the user explicitly chooses to proceed after seeing the risk.
   - If branch protection, required checks, merge queue, or ruleset behavior is unclear,
     inspect the repository policy before acting.

3. Merge according to the repository's policy.
   - Use the requested strategy; otherwise follow repository instructions or settings.
     Treat recent merged PRs as evidence of convention, not as stronger policy.
   - Treat auto-merge and merge queues as scheduling, not merge strategies. Enable them
     only when the user asked to queue the PR for later merge.

4. Verify the result from GitHub, including the PR's merged state and resulting base-branch
   commit. If the merge command exits with an error, check this state before retrying.

5. Monitor checks triggered on the resulting base-branch commit. If no post-merge checks
   exist, report that rather than describing CI as green.

6. When repository instructions say merging triggers a deployment, monitor that deployment
   and perform its documented verification. Do not infer a deployment path or trigger a
   manual deployment without authorization.

## Failure handling

- Before merging, stop and summarize any blocker.
- After merging, gather links and relevant logs for failed CI or deployment, diagnose what
  can be established safely, and ask before reverting or creating a fix-forward change.
- Finish with the PR URL, merge status and commit, post-merge CI status, documented deployment
  status and verification if applicable, and any remaining follow-up.
