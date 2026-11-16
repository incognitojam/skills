# Skills

Personal agent skills shared across Claude Code and Codex. Install them with the script for your platform:

```sh
# macOS and Linux
./link.sh
```

```powershell
# Windows
.\link.ps1
```

Each `skills/<name>/` directory is linked into `~/.claude/skills/` and into `~/.agents/skills/`, which Codex and the other agents read. Links left behind by skills removed from this repository are deleted; other links are left alone.

Personal cross-repository instructions live in [`global/AGENTS.md`](global/AGENTS.md). `./link.sh --global-instructions` or `.\link.ps1 -GlobalInstructions` links them as `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`, leaving an existing file at either location alone.

The installers also set a Git hook so that pulling `main` reruns them with the external-skills option below, so pulls need npx and network access. Run `./link.sh --help` or `Get-Help .\link.ps1` for the options.

## Skills

| Skill | Description |
| --- | --- |
| [`oracle`](skills/oracle/SKILL.md) | Consult a read-only oracle that reasons about the working tree from an independent frontier model. Use when the caller needs a senior second opinion for difficult architecture, debugging, performance, planning, design judgment, or independent review; do not use for routine searches or implementation. |
| [`revive-pr`](skills/revive-pr/SKILL.md) | Bring a left-behind pull request up to date, or decide whether it should be closed. Use when the user says "modernise" or "revive" about a pull request. |
| [`solid-query`](skills/solid-query/SKILL.md) | TanStack Solid Query patterns — options as a function, never destructuring results, reading signals inside options, dependent queries, mutations with optimistic updates, query key factories, and staleTime versus gcTime. Use when writing or reviewing `@tanstack/solid-query` code, or when a query does not refetch as expected. React Query habits break here; for core Solid reactivity see the solidjs-v2 skill. |
| [`tailwind-v4`](skills/tailwind-v4/SKILL.md) | Tailwind CSS v4 conventions and v3 differences — CSS-first `@theme` configuration, automatic content detection, renamed and removed utilities, built-in container queries, OKLCH colors, and the Vite and PostCSS setups. Use when writing Tailwind in a project on v4, migrating one from v3, or when generated utility classes or config do not behave as expected. |

## Installed skills

Third-party skills from the [open skills registry](https://skills.sh/), installed with the Skills CLI at the revisions pinned in [`external-skills.txt`](external-skills.txt). Install them all on a new machine with:

```sh
./link.sh --external-skills
```

```powershell
.\link.ps1 -ExternalSkills
```

- **Add** a skill with a line in the manifest, in the format its header describes. Skills run with full agent permissions, so read a skill's `SKILL.md` before adding it, and prefer sources with a track record.
- **Update** by merging Renovate's weekly pull requests, which appear only when a skill's folder changes upstream and link to the upstream comparison. Pulling `main` then installs the new revision. If a folder moves upstream, the Dependency Dashboard warns until its `path=` is updated.
- **Remove** a skill by deleting its selection or its line. The next install removes skills the last installed manifest selected and this one doesn't. Skills installed by hand from other sources are left alone.

`npx skills list -g` shows what is installed and where each skill came from.

| Source | Skills | Comment |
| --- | --- | --- |
| [`anthropics/skills`](https://skills.sh/anthropics/skills) | `frontend-design` |
| [`cloudflare/skills`](https://skills.sh/cloudflare/skills) | `cloudflare` |
| [`doeixd/solid-skill`](https://skills.sh/doeixd/solid-skill) | `solid-js-1x-best-practices-and-api` |
| [`github/gh-stack`](https://skills.sh/github/gh-stack) | `gh-stack` |
| [`humanlayer/skills`](https://skills.sh/humanlayer/skills) | `show-me` | Simplify explanations and diffs https://x.com/mattpocockuk/status/2095460192871698728 |
| [`khmm12/solidjs-v2-skills`](https://skills.sh/khmm12/solidjs-v2-skills) | `solidjs-v2`, `solidjs-v2-migration`, `solidjs-v2-reviewer` |
| [`neondatabase/agent-skills`](https://skills.sh/neondatabase/agent-skills) | `neon`, `neon-postgres` |
| [`t3dotgg/tstack`](https://github.com/t3dotgg/tstack) | `council`, `sol-loop` | Cross-provider review loops, run when you ask for them by name |
