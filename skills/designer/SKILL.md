---
name: designer
description: Design and implement distinctive, production-grade frontend experiences. Use when Codex is building or substantially reshaping pages, components, landing pages, dashboards, design systems, interaction states, motion, or interface copy where strong aesthetic judgment matters; do not use for headless logic or mechanical frontend fixes.
---

# Designer

Use Designer as the taste-led visible-UI implementation specialist. Keep the caller responsible for task scoping, data and state plumbing, commands, tests, screenshots, integration review, and commits.

## Prepare the work

Delegate only after the functional contract and editable scope are clear. Quote the user's original design brief and provide:

```text
Task: <the requested frontend outcome>

Scope:
- <files or frontend area Designer may edit>
- <areas it must not change>

Project constraints:
- <framework and existing component/design-system conventions>
- <relevant repository instructions>

Functional constraints:
- <behavior, data contracts, states, and accessibility requirements>

Visual context:
- <brand direction, references, existing UI, and screenshot paths>

Acceptance criteria:
- <observable desktop and mobile outcomes>
```

Do not paraphrase away concrete user preferences. Complete backend or state plumbing first when Designer needs a stable interface to design against. Note pre-existing worktree changes and ensure no other agent edits overlapping files during the delegation.

Tell the user briefly before invoking Designer and name the UI scope being delegated.

## Run Designer

Run `scripts/build.sh` from this skill directory with the shell tool's yielded or background-process mechanism. Do not append shell `&`; retain the process handle so it can be polled or stopped cleanly.

Use unique report and log paths inside an ignored `.scratch/` directory in the worktree (create it with `mkdir -p .scratch` and ensure `git check-ignore -q .scratch` succeeds first):

```bash
<path-to-this-skill>/scripts/build.sh \
  --cwd "$PWD" \
  --output .scratch/designer-<task-slug>.md \
  --log .scratch/designer-<task-slug>.log <<'PROMPT'
Task: ...

Scope:
- ...

Project constraints:
- ...

Functional constraints:
- ...

Visual context:
- ...

Acceptance criteria:
- ...
PROMPT
```

Use the default `normal` mode for routine frontend work and bounded polish. Pass `--mode best` for complex layouts, brand-defining experiences, or an explicit final-quality pass. The runner keeps Designer isolated, stateless, and limited to reading and editing files.

While Designer runs, continue only independent work and update the user at least once per minute. Wait before editing or reviewing overlapping files. On success, read the report and inspect the complete worktree diff; the report is not evidence that edits are correct.

## Validate and refine

The caller must run the repository's relevant formatter, typecheck, tests, and build. Start the app when practical and capture representative desktop and mobile screenshots, including important empty, loading, error, focus, and reduced-motion states.

If visual quality still misses the brief, make at most one stateless refinement call. Use a fresh Designer invocation and new report/log paths. Include the original brief, the first report's design direction, the current screenshot paths, concrete visual problems, and what changed since the first pass. Escalate that pass to `best` when `normal` missed the quality bar. Never resume the earlier session.

The caller owns final integration fixes, verifies that behavior and accessibility were preserved, reviews scope, and commits the result. Do not imply Designer ran commands, tests, browser checks, or commits; it cannot perform those actions.

Read [references/designer-prompt.md](references/designer-prompt.md) only when auditing or changing Designer's role. The runner loads it automatically.
