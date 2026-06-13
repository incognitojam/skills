Personal agent skills; install them with `gh skill install incognitojam/skills`, then run `./link.sh` to link the shared `AGENTS.md`, Amp settings, and Amp plugins.

The linked Amp settings keep secrets out of the repository by using environment variables. Set `AMP_TIMELINE_REMOTE_MCP_URL` locally before linking `~/.config/amp/settings.json`.

If `~/.config/amp/settings.json` already exists as a local file, move any private values into local environment variables, move the file aside, then rerun `./link.sh`.
