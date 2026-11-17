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
- When capturing a screenshot or recording, prefer a view backed by public or
  synthetic data. Only if the sole usable view exposes genuinely private data,
  redact it or say what could not be captured.

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

- For changes that affect runtime behavior, run the application or affected code
  path and inspect its actual behavior. Exercise the changed flow and relevant
  adjacent flows, check the observed results against expectations, and look for
  runtime errors and unintended effects, including browser console and server
  errors where applicable. Scale validation to the scope and risk of the change.
- Automated tests count as behavioral validation when they exercise the relevant
  behavior and check meaningful outcomes. A passing suite alone does not establish
  that the changed flow works. Continue to run required automated checks.
- In pull requests and completion reports, describe the specific scenarios
  exercised, observed outcomes, and any behavior that could not be verified,
  including why. Do not list routine checks that passed, such as linting, type
  checks, or existing test suites: CI already reports them and they add noise.
  Mention a check only when it is itself the validation for the change, such as
  for changes without runtime effects, or when it failed.

## Commit messages

- Follow the repository's existing convention when it has one: a commit template,
  documented rules in its contributing guide or agent instructions, or a pattern that
  is plainly consistent across recent `git log` history. Never reformat a repository
  onto a different convention as a side effect of an unrelated change.
- Where no convention is established, use Scoped Commits
  (https://scopedcommits.com/): a `<scope>: <description>` subject, then an optional
  body and optional trailers, each separated by a blank line.

  ```
  <scope>: <description>

  [optional body]

  [optional trailer(s)]
  ```

- The scope names the subsystem, area, or module the commit touches. Reuse the scope
  names already present in the repository's history rather than inventing new ones.
  For a change spanning several areas, prefer a broader enclosing scope, or list a
  few comma-separated scopes, or use `treewide` for genuinely repository-wide edits.
- Write the description as a concise summary of what the commit does. Reverts and
  merges keep whatever format the tooling generates.

## GitHub communication

- PR descriptions should justify the final change: explain the problem, resulting
  behavior, and relevant validation. Omit intermediate PR states and problems
  encountered during development unless they help reviewers understand or assess
  the final change. Update the description when scope changes so it reflects the
  final result.
- Write the description so a reviewer can decide from its first screen: the problem
  in a sentence or two, then what happens now as a short list or table of situations
  and what someone sees in each, rather than paragraphs of implementation. Leave
  constants, limits, and field, function, and test names in the code unless a
  reviewer needs one to judge the change or believe a claim.
- Where it helps the reader, show a change or issue in code: a minimal example of
  its behavior before and after, or an annotated call path when a bug's cause sits
  a few calls away from where it shows up.
- Upload PR evidence with `gh pr edit --attach`.
- When writing Markdown prose in GitHub pull requests or elsewhere, do not insert
  arbitrary newlines in paragraphs or list items. GitHub and editors wrap text
  according to user preferences. When writing Markdown files, follow the existing
  convention in that file or codebase.
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
- Merge a pull request only when the user explicitly asks and the target is
  unambiguous. Respect repository merge policy and stop for failed required checks,
  unresolved requested changes, conflicts, or other merge blockers unless the user
  explicitly accepts the risk.
- After attempting a merge, verify the pull request's state and resulting base-branch
  commit before reporting success or retrying an error. Check any CI triggered by that
  commit; when repository instructions say merging deploys the change, monitor and
  perform the documented verification. Ask before reverting, fixing forward, or
  triggering a manual deployment.
- When publishing text you wrote through the user's GitHub account, end it with one sentence crediting the agents: ``Written by `<label>` in [styal 🧵](https://github.com/incognitojam/styal).`` It replaces your harness's own attribution line, such as "🤖 Generated with Claude Code". Keep ` in [styal 🧵](…)` only when a styal runtime note says you run in styal; otherwise end after the label.
  - A label is `<harness>/<model id>`: the harness's command name (`claude`, `codex`, `opencode`, `pi`, `cursor`) and the model id exactly as your harness reports it, such as `codex/gpt-6.1-sol`.
  - Name each agent that worked on it, children you started included, with what it did: ``Written by `codex/gpt-6.1-sol`, reviewed by `claude/claude-opus-5-5`, in [styal 🧵](https://github.com/incognitojam/styal).`` Name an agent only when you know its label. When changing a body that already credits agents, keep them and add yourself.
  - Bodies put it after a `---` rule; comments and reviews end with it as a paragraph. Text the user wrote gets none.

## Stacked pull requests

- Make each pull request the smallest change that works on its own, even within a
  larger request or thread. Small pull requests are easier to review, merge sooner,
  and can be tested and reverted individually; unmerged code is worth nothing.
  Splitting by layer, such as frontend and backend, or into parts that only work once
  the last lands does not count.
- Stack only when a pull request builds on an earlier one that hasn't merged yet. Each
  layer must still work and ship without the layers above it. Unrelated changes stay
  separate, non-stacked pull requests.
- Manage a stack exclusively with the `gh stack` extension
  (`gh extension install github/gh-stack`), and read `gh stack --help` first where the
  `gh-stack` skill is not installed. Plain `git rebase`, `git push --force`, or manual
  retargeting of a pull request corrupt the stack's dependent branches and its GitHub
  metadata. If the extension is unavailable, report that instead of falling back to
  plain git.
- `gh stack submit` creates a pull request for each new layer, so it needs an explicit
  request whenever it would open one; pushing updates to layers you already
  own follows the ownership rule above. `gh stack merge` needs an explicit request
  like any merge. Agent-facing documentation recommends `gh stack merge --yes`, which
  suppresses the confirmation, and a merge scoped to one pull request still lands
  every unmerged layer below it. Run `gh stack view --json` first and state exactly
  which layers will land.

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
- Have a different model from the builder review what ships.
- When a mistake cannot be undone, such as changing stored data or deleting files, get
  two independent reviews, one from the strongest model, whatever the task's
  difficulty.
- Rerun with a stronger model without asking when output misses the bar.
