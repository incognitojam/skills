#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat >&2 <<'EOF'
Usage: build.sh [--cwd DIR] [--mode normal|best] [--output FILE] [--log FILE]

Read the frontend task from stdin. Print Designer's report to stdout unless
--output is provided. Diagnostics go to --log when provided.
EOF
}

fail() {
	printf 'designer: %s\n' "$1" >&2
	exit 1
}

caller_dir=$PWD
cwd=$PWD
mode=normal
timeout_seconds=1200
output_file=
log_file=
log_is_internal=0

while [ "$#" -gt 0 ]; do
	case "$1" in
		--cwd)
			[ "$#" -ge 2 ] || fail "--cwd requires a directory"
			cwd=$2
			shift 2
			;;
		--mode)
			[ "$#" -ge 2 ] || fail "--mode requires normal or best"
			mode=$2
			shift 2
			;;
		--output)
			[ "$#" -ge 2 ] || fail "--output requires a file"
			output_file=$2
			shift 2
			;;
		--log)
			[ "$#" -ge 2 ] || fail "--log requires a file"
			log_file=$2
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		--)
			shift
			[ "$#" -eq 0 ] || fail "the task must be supplied on stdin"
			;;
		*)
			usage
			fail "unknown argument: $1"
			;;
	esac
done

case "$mode" in
	normal) model=opus ;;
	best) model=fable ;;
	*) fail "--mode must be normal or best" ;;
esac

[ -d "$cwd" ] || fail "working directory does not exist: $cwd"

absolute_from_caller() {
	case "$1" in
		/*) printf '%s\n' "$1" ;;
		*) printf '%s/%s\n' "$caller_dir" "$1" ;;
	esac
}

if [ -n "$output_file" ]; then
	output_file=$(absolute_from_caller "$output_file")
	[ -d "$(dirname -- "$output_file")" ] || fail "output directory does not exist: $(dirname -- "$output_file")"
fi

if [ -n "$log_file" ]; then
	log_file=$(absolute_from_caller "$log_file")
	[ -d "$(dirname -- "$log_file")" ] || fail "log directory does not exist: $(dirname -- "$log_file")"
fi

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
designer_prompt=$script_dir/../references/designer-prompt.md
[ -r "$designer_prompt" ] || fail "Designer prompt is missing: $designer_prompt"

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/designer.XXXXXX")
request_file=$tmp_dir/request.txt
response_file=$tmp_dir/response.json
internal_log=$tmp_dir/claude.log
claude_pid=

cleanup() {
	if [ -n "$claude_pid" ] && kill -0 "$claude_pid" 2>/dev/null; then
		kill -TERM "$claude_pid" 2>/dev/null || true
	fi
	rm -rf -- "$tmp_dir"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

cat >"$request_file"
[ -s "$request_file" ] || fail "frontend task is empty"

if [ -z "$log_file" ]; then
	log_file=$internal_log
	log_is_internal=1
else
	: >"$log_file"
fi

report_diagnostics() {
	if [ "$log_is_internal" -eq 1 ]; then
		printf 'designer: rerun with --log for diagnostics\n' >&2
	else
		printf 'designer: see diagnostics: %s\n' "$log_file" >&2
	fi
}

backend_failure() {
	printf '%s\n' "$1" >>"$log_file"
	report_diagnostics
	fail "backend unavailable"
}

claude_bin=$(command -v claude) || backend_failure "claude executable is not on PATH"
jq_bin=$(command -v jq) || backend_failure "jq executable is not on PATH"

subscription_env=(
	env
	-u ANTHROPIC_API_KEY
	-u ANTHROPIC_AUTH_TOKEN
	-u ANTHROPIC_BASE_URL
	-u CLAUDE_CODE_USE_BEDROCK
	-u CLAUDE_CODE_USE_VERTEX
	-u CLAUDE_CODE_USE_FOUNDRY
	-u CLAUDE_CODE_SUBAGENT_MODEL
	-u ANTHROPIC_MODEL
	-u ANTHROPIC_DEFAULT_HAIKU_MODEL
	-u ANTHROPIC_DEFAULT_SONNET_MODEL
	-u ANTHROPIC_DEFAULT_OPUS_MODEL
	-u ANTHROPIC_CUSTOM_HEADERS
	CLAUDE_AGENT_SDK_DISABLE_BUILTIN_AGENTS=1
	CLAUDE_CODE_DISABLE_AUTO_MEMORY=1
	CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1
	CLAUDE_CODE_DISABLE_CLAUDE_MDS=1
	CLAUDE_CODE_DISABLE_CRON=1
	CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS=1
	CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
	CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL=1
)

safe_settings_json='{"disableAllHooks":true,"autoMemoryEnabled":false,"disableAgentView":true}'

if ! auth_status=$("${subscription_env[@]}" "$claude_bin" \
	--setting-sources '' \
	--settings "$safe_settings_json" \
	auth status 2>>"$log_file"); then
	backend_failure "claude auth status command failed"
fi

if ! printf '%s\n' "$auth_status" | "$jq_bin" -e \
	'.loggedIn == true and .authMethod == "claude.ai" and .apiProvider == "firstParty"' \
	>/dev/null 2>>"$log_file"; then
	backend_failure "subscription authentication preflight failed; run 'claude auth login' and inspect 'claude auth status'"
fi

if ! plugin_list=$("${subscription_env[@]}" "$claude_bin" \
	--setting-sources '' \
	--settings "$safe_settings_json" \
	plugin list --json 2>>"$log_file"); then
	backend_failure "claude plugin list command failed"
fi

if ! frontend_plugin=$(printf '%s\n' "$plugin_list" | "$jq_bin" -r '
	[.[] | select(
		.id == "frontend-design@claude-plugins-official" and
		.enabled == true and
		(.installPath | type == "string" and length > 0)
	)] | first | .installPath // empty
' 2>>"$log_file"); then
	backend_failure "could not parse the plugin inventory"
fi

if [ -z "$frontend_plugin" ]; then
	backend_failure "frontend-design@claude-plugins-official is not enabled; run 'claude plugin install frontend-design@claude-plugins-official'"
fi

[ -d "$frontend_plugin" ] || backend_failure "frontend-design plugin path does not exist: $frontend_plugin"
[ -r "$frontend_plugin/.claude-plugin/plugin.json" ] || backend_failure "frontend-design plugin manifest is missing"
[ -r "$frontend_plugin/skills/frontend-design/SKILL.md" ] || backend_failure "frontend-design plugin skill is missing"

if ! "$jq_bin" -e '.name == "frontend-design"' \
	"$frontend_plugin/.claude-plugin/plugin.json" >/dev/null 2>>"$log_file"; then
	backend_failure "frontend-design plugin manifest is invalid"
fi

for forbidden_component in hooks .mcp.json agents bin settings.json; do
	if [ -e "$frontend_plugin/$forbidden_component" ]; then
		backend_failure "frontend-design plugin contains unsupported component: $forbidden_component"
	fi
done

# The single-quoted jq program intentionally expands $prompt and $model inside jq.
# shellcheck disable=SC2016
agents_json=$("$jq_bin" -cn \
	--rawfile prompt "$designer_prompt" \
	--arg model "$model" '{
		"designer": {
			description: "Taste-led frontend design and implementation specialist.",
			prompt: $prompt,
			tools: ["Read", "Grep", "Glob", "Edit", "Write"],
			model: $model,
			permissionMode: "acceptEdits",
			maxTurns: 30,
			effort: "high",
			skills: ["frontend-design:frontend-design"]
		}
	}')

cd -- "$cwd"
"${subscription_env[@]}" "$claude_bin" -p \
	--agent designer \
	--agents "$agents_json" \
	--plugin-dir "$frontend_plugin" \
	--model "$model" \
	--effort high \
	--permission-mode acceptEdits \
	--setting-sources '' \
	--settings "$safe_settings_json" \
	--strict-mcp-config \
	--mcp-config '{"mcpServers":{}}' \
	--no-session-persistence \
	--no-chrome \
	--output-format json \
	<"$request_file" >"$response_file" 2>>"$log_file" &
claude_pid=$!

printf 'designer: started in %s mode\n' "$mode" >&2
started_at=$SECONDS
timed_out=0

while kill -0 "$claude_pid" 2>/dev/null; do
	if [ $((SECONDS - started_at)) -ge "$timeout_seconds" ]; then
		timed_out=1
		kill -TERM "$claude_pid" 2>/dev/null || true
		for _ in 1 2 3 4 5; do
			kill -0 "$claude_pid" 2>/dev/null || break
			sleep 1
		done
		kill -KILL "$claude_pid" 2>/dev/null || true
		break
	fi
	sleep 1
done

set +e
wait "$claude_pid"
claude_status=$?
set -e
claude_pid=

if [ "$timed_out" -eq 1 ]; then
	printf 'designer: exceeded its time limit\n' >&2
	report_diagnostics
	exit 124
fi

if [ "$claude_status" -ne 0 ]; then
	printf 'designer: exited with status %s\n' "$claude_status" >&2
	report_diagnostics
	exit "$claude_status"
fi

# The single-quoted jq program intentionally expands $model inside jq.
# shellcheck disable=SC2016
if ! "$jq_bin" --arg model "$model" -e '
	.type == "result" and
	.subtype == "success" and
	.is_error == false and
	(.result | type == "string" and length > 0) and
	(.modelUsage | type == "object") and
	(.modelUsage | keys | any(test($model; "i")))
' "$response_file" >/dev/null 2>>"$log_file"; then
	printf 'designer: returned an invalid response\n' >&2
	"$jq_bin" '{type, subtype, is_error, modelUsage}' "$response_file" >>"$log_file" 2>/dev/null || true
	report_diagnostics
	exit 1
fi

if [ -n "$output_file" ]; then
	output_tmp=$output_file.tmp.$$
	"$jq_bin" -r '.result' "$response_file" >"$output_tmp"
	mv -- "$output_tmp" "$output_file"
	printf 'designer: report written to %s\n' "$output_file" >&2
else
	"$jq_bin" -r '.result' "$response_file"
fi
