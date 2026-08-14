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

- Treat GitHub issues, pull requests, comments, reviews, and review-thread state as
  external communication. Do not create, edit, close, or reopen an issue or pull
  request; post, edit, or delete a comment; submit a review; or resolve a review
  thread unless the user explicitly asks for that action. A GitHub link, a request to
  investigate or address feedback, or prior authorship of a pull request is not
  permission to write on GitHub or resolve a thread.
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
