---
name: oracle
description: Consult a read-only oracle that reasons about the working tree from an independent frontier model. Use when the caller needs a senior second opinion for difficult architecture, debugging, performance, planning, design judgment, or independent review; do not use for routine searches or implementation.
---

# Oracle

Use Oracle as a slow, high-judgment escalation path. The caller remains responsible for decisions, implementation, and verification.

## Decide whether to consult

Consult Oracle when at least one of these is true:

- The problem is consequential, ambiguous, or spans several systems.
- A difficult diagnosis has resisted normal investigation.
- Architecture, API, performance, security, or migration tradeoffs need an independent view.
- A plan or completed change would benefit from adversarial senior review.
- The user explicitly asks for Oracle or a second opinion.

Do not consult for routine code search, mechanical edits, straightforward fixes, or work the caller has not investigated enough to frame precisely. Use one consultation by default. Run multiple consultations only for genuinely independent concerns or one narrow follow-up to a successful report.

Tell the user briefly before invoking Oracle and explain the question being escalated.

## Prepare the request

Give Oracle a self-contained advice packet. Include:

```text
Task: <the decision, diagnosis, or review question>

Context:
- <verified facts and relevant constraints>
- <what has already been tried>

Evidence:
- <specific files, symbols, errors, or line references to inspect>

Ask:
- <the exact recommendation or challenge wanted>
```

Quote the user's original wording when details matter. Separate facts from hypotheses. Do not paste secrets, broad logs, or large source files; Oracle can inspect the working tree with read-only tools. Ask for advice, never implementation.

## Run the consultation

Run `scripts/consult.sh` from this skill directory. Start it with the shell tool's yielded or background-process mechanism because a consultation can take several minutes. Do not append shell `&`; retain the process handle so it can be polled or stopped cleanly.

Use unique report and log paths for concurrent consultations:

```bash
<path-to-this-skill>/scripts/consult.sh \
  --cwd "$PWD" \
  --output /tmp/oracle-<task-slug>.md \
  --log /tmp/oracle-<task-slug>.log <<'PROMPT'
Task: ...

Context:
- ...

Evidence:
- ...

Ask:
- ...
PROMPT
```

The wrapper selects and enforces the advisor model, along with subscription-backed authentication, a read-only tool allowlist, a turn cap, isolated settings with hooks and MCP disabled, no session persistence, and a ten-minute timeout. Keep the default constraints unless the user explicitly requests a shorter timeout. Point `--cwd` at the narrowest relevant repository or project directory, never a broad directory such as the user's home.

While it runs, continue only independent work and give the user a short status update at least once per minute. Wait before making logically dependent decisions. On success, read only the report file. On failure, inspect only the tail of the log and either retry once with a tighter prompt or continue without Oracle while disclosing the failure.

## Follow up without resuming

Keep consultations stateless. Never resume a prior session or remove `--no-session-persistence`.

After a successful report, use at most one follow-up for the same topic. Start a fresh consultation and include the relevant parts of the prior report, state what changed since the report (including when nothing changed), and ask one narrow question. Use new report and log paths; never overwrite the earlier artifacts. If the topic needs further back-and-forth, return to the caller's own investigation or ask the user for direction.

## Apply the advice

Treat the response as advice, not authority. Check its claims against the repository and reconcile it with user and project instructions. Summarize the recommendation that influenced the work; do not imply Oracle implemented or verified anything.

Read [references/oracle-prompt.md](references/oracle-prompt.md) only when auditing or changing the advisor's role. The wrapper loads it automatically.
