Skill source files live in `skills/<skill-name>/SKILL.md`; `./link.sh` symlinks each skill dir into `~/.claude/skills/`, plus Codex-facing skills into `~/.agents/skills/`, so edits take effect immediately — no install step.

When creating or modifying a skill, load any relevant skills first. Keep skill instructions practical, concise, and reusable across repos: anything repo-specific belongs in that repo's CLAUDE.md/AGENTS.md instead. Prefer minimal `SKILL.md` frontmatter with `name` and `description`, and make descriptions trigger-oriented so agents know when to use the skill.

Keep secrets out of tracked config; use environment variables for private values instead.
