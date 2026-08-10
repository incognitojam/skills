#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

link_path() {
	local source=$1
	local target=$2
	local target_parent

	target_parent=$(dirname -- "$target")
	mkdir -p -- "$target_parent"

	if [ -L "$target" ]; then
		local current
		current=$(readlink -- "$target")
		if [ "$current" = "$source" ]; then
			printf 'ok: %s -> %s\n' "$target" "$source"
			return
		fi

		rm -- "$target"
	elif [ -e "$target" ]; then
		printf 'error: %s already exists and is not a symlink\n' "$target" >&2
		printf 'move it aside or merge it into %s, then rerun this script\n' "$source" >&2
		return 1
	fi

	ln -s -- "$source" "$target"
	printf 'linked: %s -> %s\n' "$target" "$source"
}

for skill in "$repo_root"/skills/*/; do
	link_path "${skill%/}" "$HOME/.claude/skills/$(basename -- "$skill")"
done

# Codex-facing skills live outside ~/.claude.
for skill_name in oracle designer; do
	link_path "$repo_root/skills/$skill_name" "$HOME/.agents/skills/$skill_name"
done
