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

## GitHub communication

- When writing Markdown prose in GitHub pull requests or elsewhere, do not insert
  arbitrary newlines in paragraphs or list items. GitHub and editors wrap text
  according to user preferences. When writing Markdown files, follow the existing
  convention in that file or codebase.
- Treat GitHub issues, pull requests, comments, reviews, and review-thread state as
  external communication. Do not create, edit, close, or reopen an issue or pull
  request; post, edit, or delete a comment; submit a review; or resolve a review
  thread unless the user explicitly asks for that action. A GitHub link, a request to
  investigate or address feedback, or prior authorship of a pull request is not
  permission to write on GitHub or resolve a thread.
- Merge a pull request only when the user explicitly asks and the target is
  unambiguous. Respect repository merge policy and stop for failed required checks,
  unresolved requested changes, conflicts, or other merge blockers unless the user
  explicitly accepts the risk.
- After attempting a merge, verify the pull request's state and resulting base-branch
  commit before reporting success or retrying an error. Check any CI triggered by that
  commit; when repository instructions say merging deploys the change, monitor and
  perform the documented verification. Ask before reverting, fixing forward, or
  triggering a manual deployment.
- When explicitly asked to publish text the agent wrote through the user's GitHub
  account, disclose that authorship with the actual client and model. Use
  `Written by an agent (<client>, <model>).` Do not attribute the text to the user or
  guess unknown identity details; omit any unknown detail instead.
- For an issue or pull-request body, put the disclosure in a footer separated from
  the body by a Markdown horizontal rule:

  ```markdown
  ---
  Written by an agent (Claude Code, claude-opus-5).
  ```

- For an issue or pull-request comment, review body, or inline review reply, append
  the disclosure sentence as a final paragraph without a horizontal rule. If an agent
  disclosure already exists, update it instead of adding another. Do not add a
  disclosure to text written entirely by the user.

## Stacked pull requests

- Most changes are a single pull request. Stack only when a large change splits into
  dependent, independently reviewable layers; unrelated concerns stay separate,
  non-stacked pull requests.
- Manage a stack exclusively with the `gh stack` extension
  (`gh extension install github/gh-stack`), and read `gh stack --help` first where the
  `gh-stack` skill is not installed. Plain `git rebase`, `git push --force`, or manual
  retargeting of a pull request corrupt the stack's dependent branches and its GitHub
  metadata. If the extension is unavailable, report that instead of falling back to
  plain git.
- `gh stack submit` and `gh stack merge` create or change remote pull requests, so the
  rules above apply: only when the user explicitly asks. Agent-facing documentation
  recommends `gh stack merge --yes`, which suppresses the confirmation, and a merge
  scoped to one pull request still lands every unmerged layer below it. Run
  `gh stack view --json` first and state exactly which layers will land.
