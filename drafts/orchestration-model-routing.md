# Orchestration & Model Routing (retired draft)

> Retired from `~/.claude/CLAUDE.md` on 2026-08-08 along with the `codex` skill. The
> Codex-dispatch pattern proved flaky in practice — Claude got stuck waiting on
> `codex exec`, polling logs or forcing early responses. Cross-provider subagents are
> better handled by the harness itself (as in T3 Code) than by CLI dispatch from the
> main thread. Codex itself stays in use (the oracle and designer skills remain
> Codex-facing via `~/.agents/skills/`); only the Claude-side dispatch skill is gone.
> Kept as a draft in case parts of the routing policy are worth reviving.

The main thread orchestrates; subagents do the work. Route by these defaults — rankings higher = better; cost reflects actual plan quotas (Claude Max 20x + Codex Pro 5x), not list price. Intelligence is how hard a problem you can hand the model unsupervised; taste covers UI/UX, code quality, API design, and copy.

| model         | cost | intelligence | taste |
| ------------- | ---- | ------------ | ----- |
| gpt-5.6-terra | 9    | 8            | 5     |
| gpt-5.6-sol   | 8    | 9            | 6     |
| sonnet-5      | 5    | 5            | 7     |
| opus-5        | 4    | 9            | 8     |
| fable-5       | 2    | 9            | 9     |

The gpt-5.6 ratings are provisional — sourced from OpenAI's launch benchmarks, not local evals. Terra ≈ gpt-5.5 at half the cost; Sol is the frontier tier (trades benchmarks with fable-5). Opus 5's are provisional in the same way — Anthropic's launch benchmarks put it within 0.5% of fable-5's peak CursorBench score at opus-4.8's price, so it supersedes 4.8 outright and fable-5 drops to an escalation tier. Judge outputs and adjust.

How to apply:

- **Defaults, not limits.** Standing permission to override: if a cheaper model's output misses the bar, rerun with a smarter model without asking. Judge the output, not the price tag. Escalating costs less than shipping mediocre work.
- Cost is a tie-breaker only; for anything that ships, intelligence > taste > cost.
- **Bulk/mechanical work** (clear-spec implementation, data analysis, migrations, browser/computer-use verification) → Codex (gpt-5.6-terra, effectively free) via the `codex` skill.
- **Anything user-facing** (UI, copy, API design) needs taste ≥ 7.
- **Plans, PR-stack decomposition, untangling spiralled complexity** → opus-5, escalating to fable-5 when its output misses the bar, optionally gpt-5.6-sol as an extra independent perspective.
- gpt-5.6-luna (cheapest tier) has no routing role — terra is already effectively free on plan quota, and luna measured _slower_ than terra on identical explore dispatches (~2x the tokens; wall-time follows token count, not model size). Don't use `ultra` effort (multi-agent fan-out, quota-heavy, unvalidated here).
- Never use haiku. Search/exploration subagents run on sonnet-5 — the built-in Explore agent defaults to a fast haiku-class model, so every Explore dispatch must pass an explicit `model: "sonnet"`.
- Mechanics: the Agent tool `model` parameter only takes Claude models (sonnet-5, opus-5, fable-5) — pass the `opus` alias so pinned routing tracks the latest Opus. The gpt-5.6 models run via the Codex CLI, guided by the `codex` skill: the dispatcher authors the prompt itself and runs `codex exec` via background Bash; Codex owns the work end to end (implement, test, commit), and verification comes from the independent reviewer.
- **The main thread orchestrates; it doesn't build.** Keep code, diffs, and logs out of main context — only report packets come back (`codex exec` is a dispatch, not work: progress streams to a log file, only the `-o` report is read). A trivial tweak touching a file or two is fine; the moment an edit means reading several files or wants tests/review, stop and dispatch — even mid-edit.
- Worktrees are harness-owned: t3 code creates one per session (the main thread lives inside it) and runs the repo's setup itself; read-only/research sessions can skip the worktree entirely. Builders work in place in the session's worktree. Do not spawn nested worktrees (`isolation: "worktree"`) — t3 doesn't run setup for those; parallel tasks are parallel t3 sessions instead.
- Human gates: get plan approval before multi-PR work starts, and approval before any merge.
