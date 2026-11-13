#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
link_global_instructions=false
install_external_skills=false

usage() {
	printf 'Usage: %s [--global-instructions] [--external-skills]\n' "$(basename -- "$0")"
	printf '\n'
	printf 'Links personal skills by default. With --global-instructions, also links\n'
	printf 'global/AGENTS.md for Claude Code and Codex without replacing existing files.\n'
	printf 'With --external-skills, also installs the third-party skills listed in\n'
	printf 'external-skills.txt from the registry. Installing needs network access and\n'
	printf 'removes CLI-recorded skills the manifest no longer selects for Claude Code and Codex.\n'
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--global-instructions)
			link_global_instructions=true
			;;
		--external-skills)
			install_external_skills=true
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

# Keep links current after each pull. Outside a clone, there is nothing to pull.
if git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
	git -C "$repo_root" config core.hooksPath .githooks
fi

for skill in "$repo_root"/skills/*/; do
	skill_name=$(basename -- "$skill")

	link_path "${skill%/}" "$HOME/.claude/skills/$skill_name"
	# Codex and the other agents read ~/.agents/skills.
	link_path "${skill%/}" "$HOME/.agents/skills/$skill_name"
done

# Skills removed from this repository leave links behind. Only touch broken links
# into this checkout, since these directories also hold other people's skills.
remove_stale_links() {
	local link
	for link in "$1"/*; do
		[ -L "$link" ] && [ ! -e "$link" ] || continue
		case $(readlink -- "$link") in
			"$repo_root"/skills/*)
				rm -- "$link"
				printf 'removed: %s\n' "$link"
				;;
		esac
	done
}

remove_stale_links "$HOME/.claude/skills"
remove_stale_links "$HOME/.agents/skills"

if [ "$link_global_instructions" = true ]; then
	link_path_if_absent "$repo_root/global/AGENTS.md" "$HOME/.claude/CLAUDE.md"
	link_path_if_absent "$repo_root/global/AGENTS.md" "$HOME/.codex/AGENTS.md"
fi

if [ "$install_external_skills" = true ]; then
	manifest="$repo_root/external-skills.txt"

	if ! command -v npx >/dev/null 2>&1; then
		printf 'error: npx is required to install external skills\n' >&2
		exit 1
	fi

	if [ ! -f "$manifest" ]; then
		printf 'error: %s is missing\n' "$manifest" >&2
		exit 1
	fi

	# Read the manifest on fd 3 so npx keeps its own stdin.
	while IFS= read -r package <&3 || [ -n "$package" ]; do
		package=${package%%#*}
		package=${package%$'\r'}
		read -r -a package_args <<< "$package"
		[ -n "${package_args[0]:-}" ] || continue

		printf 'installing: %s\n' "$package"
		# JSON mode fails if any requested skill is missing, even when others match.
		npx --yes skills@1.7.6 add "${package_args[@]}" --global --yes --json --agent claude-code codex
	done 3<"$manifest"

	node "$repo_root/scripts/prune-external-skills.mjs" "$manifest"
fi
