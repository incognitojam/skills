#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
link_global_instructions=false

usage() {
	printf 'Usage: %s [--global-instructions]\n' "$(basename -- "$0")"
	printf '\n'
	printf 'Links personal skills by default. With --global-instructions, also links\n'
	printf 'global/AGENTS.md for Claude Code and Codex without replacing existing files.\n'
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--global-instructions)
			link_global_instructions=true
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			printf 'error: unknown argument: %s\n\n' "$1" >&2
			usage >&2
			exit 2
			;;
	esac
	shift
done

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

link_path_if_absent() {
	local source=$1
	local target=$2

	if [ -L "$target" ]; then
		local current
		current=$(readlink -- "$target")
		if [ "$current" = "$source" ]; then
			printf 'ok: %s -> %s\n' "$target" "$source"
		else
			printf 'skipped: %s already exists as a symlink to %s\n' "$target" "$current"
		fi
		return
	fi

	if [ -e "$target" ]; then
		printf 'skipped: %s already exists and was left unchanged\n' "$target"
		return
	fi

	link_path "$source" "$target"
}

for skill in "$repo_root"/skills/*/; do
	link_path "${skill%/}" "$HOME/.claude/skills/$(basename -- "$skill")"
done

# Codex-facing skills live outside ~/.claude.
for skill_name in oracle designer; do
	link_path "$repo_root/skills/$skill_name" "$HOME/.agents/skills/$skill_name"
done

if [ "$link_global_instructions" = true ]; then
	link_path_if_absent "$repo_root/global/AGENTS.md" "$HOME/.claude/CLAUDE.md"
	link_path_if_absent "$repo_root/global/AGENTS.md" "$HOME/.codex/AGENTS.md"
fi
