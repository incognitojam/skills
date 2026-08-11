# Skills

Personal agent skills shared across Claude Code and Codex. Run `./link.sh` to symlink them into place:

- All `skills/<name>/` directories are linked into `~/.claude/skills/`.
- `oracle` and `designer` are additionally linked into `~/.agents/skills/` for Codex.

Personal cross-repository instructions are tracked separately in
[`global/AGENTS.md`](global/AGENTS.md). Install them explicitly with:

```sh
./link.sh --global-instructions
```

This links the same file as `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`. Existing
files and unrelated symlinks at either location are reported and left unchanged, so
the default `./link.sh` remains portable for people with their own global instructions.

## Skills

| Skill | Description |
| --- | --- |
| [`designer`](skills/designer/SKILL.md) | Design and implement distinctive, production-grade frontend experiences. Use when Codex is building or substantially reshaping pages, components, landing pages, dashboards, design systems, interaction states, motion, or interface copy where strong aesthetic judgment matters; do not use for headless logic or mechanical frontend fixes. |
| [`merging-prs`](skills/merging-prs/SKILL.md) | Safely merge or land a GitHub pull request and verify the result. Use only when explicitly asked to merge, land, or ship a PR. |
| [`oracle`](skills/oracle/SKILL.md) | Consult a read-only oracle that reasons about the working tree from an independent frontier model. Use when the caller needs a senior second opinion for difficult architecture, debugging, performance, planning, design judgment, or independent review; do not use for routine searches or implementation. |
