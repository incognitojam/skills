Skill source files live in `skills/<skill-name>/SKILL.md`. Installed global skill files may contain installer-added frontmatter, such as metadata about the local source path, so don't assume installed copies are byte-identical to the repo sources.

When creating or modifying a skill, load any relevant skills first. Keep skill instructions practical, concise, and easy to reuse across repos. Prefer minimal `SKILL.md` frontmatter with `name` and `description`, and make descriptions trigger-oriented so agents know when to use the skill.

Use source documentation for the systems being configured. For Amp behavior and configuration, follow the Amp manual: http://ampcode.com/manual

Use `gh skill` to install skills. Use `./link.sh` to link shared config files into `~/.config`.

Shared Amp/user config source files live under `.config/`. Keep secrets out of tracked config; use environment variables for private values instead.

Use Bun for validation when code or config changes need checking:

```sh
bun run check
```

Use `bun run format` only when formatting changes are intended.
