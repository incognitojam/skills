#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat >&2 <<'EOF'
Usage: consult.sh [--cwd DIR] [--timeout SECONDS] [--output FILE] [--log FILE]

Read the consultation request from stdin. Print Oracle's report to stdout unless
--output is provided. Diagnostics go to --log when provided.
EOF
}

fail() {
	printf 'oracle: %s\n' "$1" >&2
	exit 1
}

caller_dir=$PWD
cwd=$PWD
timeout_seconds=600
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
		--timeout)
			[ "$#" -ge 2 ] || fail "--timeout requires seconds"
			timeout_seconds=$2
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
			[ "$#" -eq 0 ] || fail "the request must be supplied on stdin"
			;;
		*)
			usage
			fail "unknown argument: $1"
			;;
	esac
done

case "$timeout_seconds" in
	''|*[!0-9]*) fail "--timeout must be a positive integer" ;;
esac
[ "$timeout_seconds" -gt 0 ] || fail "--timeout must be greater than zero"
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

claude_bin=$(command -v claude) || fail "claude is not installed or not on PATH"
jq_bin=$(command -v jq) || fail "jq is not installed or not on PATH"

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
oracle_prompt=$script_dir/../references/oracle-prompt.md
[ -r "$oracle_prompt" ] || fail "Oracle prompt is missing: $oracle_prompt"

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/oracle.XXXXXX")
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
[ -s "$request_file" ] || fail "consultation request is empty"

if [ -z "$log_file" ]; then
	log_file=$internal_log
	log_is_internal=1
else
	: >"$log_file"
fi

report_diagnostics() {
	if [ "$log_is_internal" -eq 1 ]; then
		if [ -s "$log_file" ]; then
			printf 'oracle: diagnostics follow\n' >&2
			tail -n 30 "$log_file" >&2 || true
		fi
	else
		printf 'oracle: diagnostics: %s\n' "$log_file" >&2
	fi
}

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
	report_diagnostics
	fail "could not read Claude Code authentication status"
fi

if ! printf '%s\n' "$auth_status" | "$jq_bin" -e \
	'.loggedIn == true and .authMethod == "claude.ai" and .apiProvider == "firstParty"' \
	>/dev/null 2>>"$log_file"; then
	report_diagnostics
	fail "Claude Code is not using a first-party claude.ai subscription; run 'claude auth login' and check 'claude auth status'"
fi

# The single-quoted jq program intentionally expands $prompt inside jq.
# shellcheck disable=SC2016
agents_json=$("$jq_bin" -cn --rawfile prompt "$oracle_prompt" '{
	oracle: {
		description: "Read-only senior engineering advisor for hard problems and independent review.",
		prompt: $prompt,
		tools: ["Read", "Grep", "Glob"],
		model: "fable",
		permissionMode: "dontAsk",
		maxTurns: 12,
		effort: "high"
	}
}')

cd -- "$cwd"
"${subscription_env[@]}" "$claude_bin" -p \
	--agent oracle \
	--agents "$agents_json" \
	--model fable \
	--effort high \
	--permission-mode dontAsk \
	--setting-sources '' \
	--settings "$safe_settings_json" \
	--strict-mcp-config \
	--mcp-config '{"mcpServers":{}}' \
	--disable-slash-commands \
	--no-session-persistence \
	--no-chrome \
	--output-format json \
	<"$request_file" >"$response_file" 2>>"$log_file" &
claude_pid=$!

printf 'oracle: consultation started (timeout %ss)\n' "$timeout_seconds" >&2
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
	printf 'oracle: consultation exceeded %ss\n' "$timeout_seconds" >&2
	report_diagnostics
	exit 124
fi

if [ "$claude_status" -ne 0 ]; then
	printf 'oracle: Claude Code exited with status %s\n' "$claude_status" >&2
	report_diagnostics
	exit "$claude_status"
fi

if ! "$jq_bin" -e '
	.type == "result" and
	.subtype == "success" and
	.is_error == false and
	(.result | type == "string" and length > 0) and
	(.modelUsage | type == "object") and
	(.modelUsage | keys | any(test("fable"; "i")))
' "$response_file" >/dev/null 2>>"$log_file"; then
	printf 'oracle: Claude returned an invalid, failed, or non-Fable response\n' >&2
	"$jq_bin" '{type, subtype, is_error, modelUsage}' "$response_file" >&2 2>/dev/null || true
	report_diagnostics
	exit 1
fi

if [ -n "$output_file" ]; then
	output_tmp=$output_file.tmp.$$
	"$jq_bin" -r '.result' "$response_file" >"$output_tmp"
	mv -- "$output_tmp" "$output_file"
	printf 'oracle: report written to %s\n' "$output_file" >&2
else
	"$jq_bin" -r '.result' "$response_file"
fi
