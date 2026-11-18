# Personal agent instructions

## Personal data

- Do not introduce private personal data into anything that lands in a repository or
  is shared externally: code, tests, fixtures, screenshots, recordings, logs, and
  commit messages. Invent synthetic values rather than reaching for a real name,
  email address, phone number, physical address, credential, or internal hostname.
- This is a rule about not creating new exposure, not a redaction chore. Data that is
  already public in the context being worked in — authors and emails in git history,
  participants on a public pull request or issue, an open-source codebase — needs no
  masking. Quote and reproduce it normally.
- For screenshots and recordings, prefer a view backed by public or synthetic data;
  otherwise redact, or say what could not be captured.

## Scratch files

- Keep scratch and intermediate work inside the repository worktree being worked in,
  under an ignored `.scratch/` directory at its root. That covers notes, plans,
  reports from delegated agents, draft patches, logs, and one-off scripts. Do not use
  `/tmp`, `$TMPDIR`, the home directory, or a scratchpad directory your harness
  offers: work there is invisible to the user and to `git status`, collides across
  concurrent sessions and worktrees, and disappears on reboot.
- Before writing there, confirm `git check-ignore -q .scratch` succeeds. If it fails,
  add `.scratch/` to `.git/info/exclude` rather than to the tracked `.gitignore`,
  which the user may not want changed. Never commit anything from `.scratch/`.
- Name files by task, `.scratch/<task-slug>-<purpose>.<ext>`, so concurrent sessions
  in the same worktree do not overwrite one another.
- Outside a repository, or when a tool insists on a temporary path, use a
  task-specific subdirectory such as `mktemp -d` and tell the user where it is.
  Caches and configuration that tools own (package managers, `gh`, agent memory)
  stay where those tools put them.
- Run one-off Python that needs third-party packages with `uv run --with <package>`.

## Verification and validation

- For changes that affect runtime behavior, run the affected code path and check
  what it actually does, including adjacent flows and runtime errors, in proportion
  to the change's scope and risk. Automated tests count when they exercise the
  changed behavior and check meaningful outcomes; a passing suite alone does not
  establish that the changed flow works.
- In pull requests and completion reports, describe the specific scenarios
  exercised, observed outcomes, and any behavior that could not be verified,
  including why. Do not list routine checks that passed, such as linting, type
  checks, or existing test suites: CI already reports them and they add noise.
  Mention a check only when it is itself the validation for the change, such as
  for changes without runtime effects, or when it failed.

## Documentation

- Document each thing in one place. Do not spread the same explanation across code
  comments, user docs, agent instructions, and config files: the copies drift apart
  and nobody knows which is right.
- Before writing documentation, find where the topic is already covered and update
  that. Where another file needs it, link or point to that place instead of
  restating it.

## Codebase ownership

- In a repository that belongs to the user, you are the owner and long-term
  maintainer of the codebase, and its design is up to you. You answer for the state
  you leave it in, not only for the lines the task named.
- When something in the area you are working in is wrong or in the wrong place, such
  as misplaced documentation, a duplicated explanation, or a stale comment, do not
  leave it as found out of caution. Fix it, in the right place: a fix the task
  depends on goes in the task's change, and anything else goes in its own pull
  request, never as a drive-by in the current one.
- Make that separate fix on its own branch once the task is done. Then reread the
  diff as its reviewer would: is the problem real, is this the right fix, and is it
  worth a reviewer's time? If so, open its pull request without asking; this is the
  explicit request "GitHub communication" calls for. If not, drop it and say why.
- Report every change you made beyond what the task asked for, however small, and
  every separate fix you prepared or left undone, in your summary.
- In a repository that belongs to someone else, such as an upstream project the user
  contributes to, none of this applies: change as little as the task needs.
- Apart from opening that pull request, this does not loosen the limits on external
  communication and irreversible actions set elsewhere in these instructions.

## Commit messages

- Follow the repository's existing convention when it has one: a commit template,
  documented rules in its contributing guide or agent instructions, or a pattern that
  is plainly consistent across recent `git log` history. Never reformat a repository
  onto a different convention as a side effect of an unrelated change.
- Where no convention is established, use Scoped Commits
  (https://scopedcommits.com/): a `<scope>: <description>` subject, then an optional
  body and optional trailers, each separated by a blank line.
- The scope names the subsystem, area, or module the commit touches. Reuse the scope
  names already present in the repository's history rather than inventing new ones.
  For a change spanning several areas, prefer a broader enclosing scope, or list a
  few comma-separated scopes, or use `treewide` for genuinely repository-wide edits.
- Reverts and merges keep whatever format the tooling generates.

## GitHub communication

- A PR description justifies the final change so a reviewer can decide from its
  first screen: the problem, what happens now, and how it was validated, at a length
  that fits the change. Leave out intermediate states and development history, and
  update it when scope changes.
- Where there is something concrete to show, such as the message someone now sees
  or the line that changed, show it instead of describing it. Use a list or table
  only to compare several situations. Leave constants, limits, and field, function,
  and test names in the code unless a reviewer needs one to judge the change or
  believe a claim.
- Upload PR evidence with `gh pr edit --attach`.
- In text posted to GitHub, such as PR bodies and comments, do not hard-wrap
  paragraphs or list items; GitHub wraps them. In Markdown files, follow the file's
  existing convention.
- Treat GitHub issues, pull requests, comments, reviews, and review-thread state as
  external communication. Do not create, edit, close, or reopen an issue or pull
  request; post, edit, or delete a comment; submit a review; or resolve a review
  thread unless the user explicitly asks for that action. A GitHub link, a request to
  investigate, or having authored a pull request in an earlier task is not
  permission to write on GitHub or resolve a thread.
- Asking you to open a pull request, or to work on an existing one, is that explicit
  request for the pull request's ongoing work: you own it for the task.
  Without asking again, you may push to the pull request's branch; update its title,
  body, and attached evidence; mark a draft ready for review once the verification
  and evidence the repository's instructions call for are in place; and reply to and
  resolve review feedback on it. Merging, closing, and reopening still need their
  own explicit request, as does commenting on, reviewing, or resolving threads on
  issues and pull requests you do not own.
- Monitor a pull request you own after opening it or pushing to it, using the
  harness's watch tool if it has one, and handle the checks and review feedback that
  come in.
- You also own a branch you created for the task or were asked to work on, and
  the branch of a pull request you own. You may rewrite and force push an owned branch
  other than the default branch, after checking that the push discards only commits you
  mean to replace. Pin the lease to the commit you checked:
  `git push --force-with-lease=<branch>:<sha>`.
- Before merging, be sure which pull request is meant. Respect repository merge
  policy and stop for failed required checks, unresolved requested changes,
  conflicts, or other merge blockers unless the user explicitly accepts the risk.
- After attempting a merge, verify the pull request's state and resulting base-branch
  commit before reporting success or retrying an error. Check any CI triggered by that
  commit; when repository instructions say merging deploys the change, monitor and
  perform the documented verification. Ask before reverting, fixing forward, or
  triggering a manual deployment.
- When publishing text you wrote through the user's GitHub account, end it with one sentence crediting the agents: ``Written by `<label>` in [styal 🧵](https://github.com/incognitojam/styal).`` It replaces your harness's own attribution line, such as "🤖 Generated with Claude Code". Keep ` in [styal 🧵](…)` only in a pull request body, and only when a styal runtime note says you run in styal; otherwise end after the label.
  - A label is `<harness>/<model id>`: the harness's command name (`claude`, `codex`, `opencode`, `pi`, `cursor`) and the model id exactly as your harness reports it, such as `codex/gpt-6.2-sol`.
  - Name each agent that worked on it, children you started included, with what it did: ``Written by `codex/gpt-6.2-sol`, reviewed by `claude/claude-opus-5-5`, in [styal 🧵](https://github.com/incognitojam/styal).`` Name an agent only when you know its label. When changing a body that already credits agents, keep them and add yourself.
  - Bodies put it after a `---` rule; comments and reviews end with it as a paragraph. Text the user wrote gets none.

## Pull request size and stacking

- Make each pull request the smallest change that works on its own, even within a
  larger request or thread. Small pull requests are easier to review, merge sooner,
  and can be tested and reverted individually; unmerged code is worth nothing.
  Splitting by layer, such as frontend and backend, or into parts that only work once
  the last lands does not count.
- Stack only when a pull request builds on an earlier one that hasn't merged yet. Each
  layer must still work and ship without the layers above it. Unrelated changes stay
  separate, non-stacked pull requests.
- Manage a stack only with the `gh stack` extension, reading `gh stack --help` first
  where the `gh-stack` skill is not installed. Plain `git rebase`, `git push --force`,
  or manual retargeting corrupt the stack's dependent branches and GitHub metadata.
  If the extension is missing, install it with `gh extension install github/gh-stack`;
  if you cannot, say so instead of falling back to plain git.
- `gh stack submit` and `gh stack merge` need the same explicit request as opening
  or merging any pull request, whatever the `gh-stack` skill suggests about `--yes`.
  A merge scoped to one pull request also lands every unmerged layer below it: run
  `gh stack view --json` first and state which layers will land.

## Delegating work

Where the harness offers subagent or delegation tools, pick the model from these
ratings. Higher is better, and cost reflects subscription quotas, not list price.

| Model     | Cost | Intelligence | Taste |
| --------- | ---- | ------------ | ----- |
| Haiku     | 9    | 4            | 4     |
| GPT Sol   | 8    | 7            | 4     |
| GPT Astra | 6    | 9            | 5     |
| Opus      | 4    | 9            | 8     |
| Fable     | 2    | 10           | 9     |

- Pick the cheapest model that clears the bar for the task. Mechanical work to a clear
  spec needs little. A plan or a hard diagnosis needs high intelligence. Anything
  user-facing needs taste of 7 or more.
- Have a different model from the builder review non-trivial changes before they
  ship.
- When a mistake cannot be undone, such as changing stored data or deleting files, get
  two independent reviews, one from the strongest model, whatever the task's
  difficulty.
- Rerun with a stronger model without asking when output misses the bar.
