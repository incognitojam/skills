---
name: revive-pr
description: Bring a left-behind pull request up to date, or decide whether it should be closed. Use when the user says "modernise" or "revive" about a pull request.
---

# Revive a pull request

Establish the PR's intent. Find the original thread if possible; it may be on
another environment. Read the title, body, linked issues, commits, review
threads, and complete diff, and look for why it stalled. State the smallest
coherent goal the PR was trying to accomplish before judging its implementation.

If the user asks whether it should be updated or closed, compare that goal with
the current base branch, recommend one with evidence, and change nothing.

To take it over, move to a worktree and check out the branch. Take
responsibility for finishing the original goal. Do not defend an implementation
just because another agent already built it. Rework what is necessary to finish
the same goal, not unrelated features. Simplify the implementation without
dropping intended behavior or surfaces.

Update the branch (you may force push), and update the PR, monitoring checks
until completion and marked ready for review. Follow existing guidance around
providing evidence.

If someone else wrote the PR, keep their original commits with attribution and
work on top of them rather than force pushing over them.
