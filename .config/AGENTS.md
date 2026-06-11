## Git Guidelines

- **Scoped commits**: Format as `<scope>: <description>` with an optional body/trailers. Scope is the subsystem touched (e.g., `api:`, `web:`, `sync:`); prefer deriving it from existing repo history.
- **Short titles**: Under 50 chars preferred, 72 max.
- **Atomic and self-justifying**: Each commit (and PR) is one logical change, exercised at merge — not scaffolding nothing calls yet. If a feature has multiple moving parts, commit them together rather than splitting into non-functional pieces.
- **No dead code**: Nothing without a caller. Wire it up as it lands, or feature-flag it. When "keep it small" conflicts with "no dead code," no-dead-code wins — resolve with vertical slicing or a flag.
- **Slice vertically**: Build a thin end-to-end path first, then widen — not horizontally ("all backend, then all frontend"). Split frontend/backend only along a real seam (e.g. a versioned API contract) where each side is independently testable.
- **Separate mechanical from behavioral changes**: Renames, formatting, and moves go in distinct commits from behavioral changes (and ideally separate branches) to avoid introducing regressions.
- **Branch naming**: Name branches after the logical change, not the layer. Prefer `add-rate-limit-to-login` over `backend-changes`.
- **Stack small dependent PRs**: Order them so each rung is consumed as it lands. If a PR is one rung in a stack, state what it depends on and what consumes it.
- **Commit why-rule**: Describe *what* changed. Add a reason only when you can cite a specific checkable artifact — a failing test, error/stack trace, API limit, measured behavior, or the issue for this slice. The artifact must explain why *this* change in *this* form, not just name the broader task. Put the reason in the body/trailer. Reference the issue there with `Closes #N` only when the commit resolves it, otherwise `Refs #N` / `Part of #N`. No artifact → no invented rationale; describe plainly or let a self-evident diff speak for itself.
- **Single source of truth**: Define each constant, config value, or type once — others import or derive it. Don't restate in comments/docs what the code, types, or schema already express; state each fact once, closest to where it's enforced.
- **Clean up before opening a PR**: Rebase/squash the branch. Run the project's full test/check command before pushing — it must pass.
- **Link the issue in the PR body**: `Closes #N` if the PR resolves it, `Refs #N` / `Part of #N` if partial. No closing keyword unless it genuinely closes the issue.

## Fail Fast — No Silent Defaults

**NEVER create defaults that mask failures.** If a required config, environment var or dependency is missing, RAISE AN EXCEPTION AT INIT. Do not silently substitute a "safe" fallback that makes code appear to work while actually being broken. Swallowing errors to avoid exceptions is not defensive programming - it's sabotage. Your collaborators will waste hours debugging phantom failures that surface far from the root cause. A loud crash at startup is infinitely preferable to silent corruption downstream. If the system cannot operate correctly, it must refuse to operate at all.

## Test Data

- **No real personal data in tests** — use generic names ("Alice", "Bob"), `example.com` emails, and placeholder locations.

## Bash Guidelines

### Avoid commands that cause output buffering issues
- DO NOT pipe output through `head`, `tail`, `less`, or `more` when monitoring or checking command output.
- DO NOT use `| head -n X` or `| tail -n X` to truncate output - these cause buffering problems.
- Instead, let commands complete fully, or use `--max-lines` flags if the command supports them.
- For log monitoring, prefer reading files directly rather than piping through filters.

### When checking command output
- Run commands directly without pipes when possible.
- If you need to limit output, use command-specific flags (e.g., `git log -n 10` instead of `git log | head -10`).
- Avoid chained pipes that can cause output to buffer indefinitely.
