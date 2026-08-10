# skills

Personal agent skills. Run `./link.sh` to symlink them into place:

- `skills/<name>/` → `~/.claude/skills/<name>` — personal skills, available in every session.
- `skills/oracle/` → `~/.agents/skills/oracle` — the read-only Fable advisor, discoverable by Codex across repositories.
- `skills/designer/` → `~/.agents/skills/designer` — the taste-led frontend implementation specialist, discoverable by Codex across repositories.

Retired guidance lives in `drafts/` for reference — nothing there is linked or loaded anywhere.

Repo-specific conventions live in each repo's own CLAUDE.md/AGENTS.md; this repo holds only what applies across all of them. Keep secrets out of tracked config.
