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

The scripts link them into place as follows:

- All `skills/<name>/` directories are linked into `~/.claude/skills/`.
- Each is also linked into `~/.agents/skills/`, which Codex and the other agents read.
- Links left behind by skills removed from this repository are deleted. Other links are left alone.

Personal cross-repository instructions are tracked separately in [`global/AGENTS.md`](global/AGENTS.md). Install them explicitly with:

```sh
./link.sh --global-instructions
```

```powershell
.\link.ps1 -GlobalInstructions
```

This links the same file as `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`. Existing files and unrelated links at either location are reported and left unchanged, so the default installers remain portable for people with their own global instructions. On Windows, skill directories use junctions; global instruction files use symbolic links with a hard-link fallback.

`link.sh` also sets `core.hooksPath` so that pulling `main` into the main checkout reruns it, which picks up added skills on macOS and Linux. Edits to existing skills need no rerun, because they are symlinks. External skills are still installed by hand.

## Skills

| Skill | Description |
| --- | --- |
| [`oracle`](skills/oracle/SKILL.md) | Consult a read-only oracle that reasons about the working tree from an independent frontier model. Use when the caller needs a senior second opinion for difficult architecture, debugging, performance, planning, design judgment, or independent review; do not use for routine searches or implementation. |
| [`revive-pr`](skills/revive-pr/SKILL.md) | Bring a left-behind pull request up to date, or decide whether it should be closed. Use when the user says "modernise" or "revive" about a pull request. |
| [`solid-query`](skills/solid-query/SKILL.md) | TanStack Solid Query patterns — options as a function, never destructuring results, reading signals inside options, dependent queries, mutations with optimistic updates, query key factories, and staleTime versus gcTime. Use when writing or reviewing `@tanstack/solid-query` code, or when a query does not refetch as expected. React Query habits break here; for core Solid reactivity see the solidjs-v2 skill. |
| [`tailwind-v4`](skills/tailwind-v4/SKILL.md) | Tailwind CSS v4 conventions and v3 differences — CSS-first `@theme` configuration, automatic content detection, renamed and removed utilities, built-in container queries, OKLCH colors, and the Vite and PostCSS setups. Use when writing Tailwind in a project on v4, migrating one from v3, or when generated utility classes or config do not behave as expected. |

## Installed skills

Third-party skills installed from the [open skills registry](https://skills.sh/) with the Skills CLI. Their files live outside this repository, under `~/.agents/skills/` or `~/.claude/skills/`, but the set is tracked here in [`external-skills.txt`](external-skills.txt). Install every skill in that manifest on a new machine with:

```sh
./link.sh --external-skills
```

```powershell
.\link.ps1 -ExternalSkills
```

Rerunning installs new manifest entries and repairs missing skills or agent links, but skips completed installs without invoking the CLI or downloading repositories again. Entries from the same repository are batched into one CLI invocation. Installation requires Node.js and npx; personal linking alone does not.

For individual skills, the installer checks the Skills CLI's global lock file and verifies that `SKILL.md` exists for both agents. Whole-repository entries need one successful install through these scripts to record which skills belong to the complete install. That receipt is saved as `.external-skills-install.json` beside the CLI's lock file, normally under `~/.agents/` (or `$XDG_STATE_HOME/skills/` when set).

To refresh all manifest entries, including discovering newly added skills in whole-repository entries, run:

```sh
./link.sh --refresh-external-skills
```

```powershell
.\link.ps1 -RefreshExternalSkills
```

The refresh flag includes external installation, so it can be used on its own. To drop a skill, delete its line and run `npx skills remove <skill> -g`. `npx skills list -g` reports what is installed and where each skill came from. Run `./link.sh --help` or `Get-Help .\link.ps1` for what the flags do.

| Source | Skills | Comment |
| --- | --- | --- |
| [`anthropics/skills`](https://skills.sh/anthropics/skills) | `frontend-design` |
| [`clerk/skills`](https://skills.sh/clerk/skills) | `clerk` router plus 20 framework, billing, orgs, webhooks, and testing skills |
| [`doeixd/solid-skill`](https://skills.sh/doeixd/solid-skill) | `solid-js-1x-best-practices-and-api` |
| [`github/gh-stack`](https://skills.sh/github/gh-stack) | `gh-stack` |
| [`humanlayer/skills`](https://skills.sh/humanlayer/skills) | `show-me` | Simplify explanations and diffs https://x.com/mattpocockuk/status/2095460192871698728 |
| [`khmm12/solidjs-v2-skills`](https://skills.sh/khmm12/solidjs-v2-skills) | `solidjs-v2`, `solidjs-v2-migration`, `solidjs-v2-reviewer` |
| [`t3dotgg/tstack`](https://github.com/t3dotgg/tstack) | `council`, `sol-loop` | Cross-provider review loops, run when you ask for them by name |

Skills run with full agent permissions, so read a skill's `SKILL.md` before adding it to the manifest, and prefer sources with a track record. Nothing is pinned: new installs and explicit refreshes take whatever the source publishes at that moment. Skipped installs keep their existing contents.
