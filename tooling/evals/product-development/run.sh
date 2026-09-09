#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
CASES_FILE="$SCRIPT_DIR/cases.json"
CASE_CONTRACT_FILE="$SCRIPT_DIR/case-contract.jq"
SCHEMA_FILE="$SCRIPT_DIR/decision.schema.json"
PROMPT_CONTRACT_FILE="$SCRIPT_DIR/routing-prompt.md"
HARNESS_FILE="$REPO_ROOT/agents/skills/owned/product-development-workflow/SKILL.md"
CODEX_REFERENCE_FILE="$REPO_ROOT/agents/skills/owned/product-development-workflow/references/codex-cli.md"
CLAUDE_REFERENCE_FILE="$REPO_ROOT/agents/skills/owned/product-development-workflow/references/claude-code.md"
ADAPTER_REVISION="2"
PROVIDER=""
MODEL=""
EFFORT="medium"
CASE_ID=""
OUTPUT_FILE=""
OUTPUT_TEMP=""
FORCE_OUTPUT=0
LIST_ONLY=0

usage() {
  echo "Usage: $0 --provider codex|claude --model MODEL [--effort LEVEL] [--case ID] [--harness FILE] [--output FILE] [--force]"
  echo "       $0 --list"
}

fail() {
  echo "error: $*" >&2
  exit 2
}

sha256_file() {
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    fail "sha256sum or shasum is required"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) [[ $# -ge 2 ]] || fail "--provider requires a value"; PROVIDER="$2"; shift ;;
    --model) [[ $# -ge 2 ]] || fail "--model requires a value"; MODEL="$2"; shift ;;
    --effort) [[ $# -ge 2 ]] || fail "--effort requires a value"; EFFORT="$2"; shift ;;
    --case) [[ $# -ge 2 ]] || fail "--case requires a value"; CASE_ID="$2"; shift ;;
    --harness) [[ $# -ge 2 ]] || fail "--harness requires a value"; HARNESS_FILE="$2"; shift ;;
    --output) [[ $# -ge 2 ]] || fail "--output requires a value"; OUTPUT_FILE="$2"; shift ;;
    --force) FORCE_OUTPUT=1 ;;
    --list) LIST_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
  shift
done

command -v jq >/dev/null || fail "jq is required"
jq -e -f "$CASE_CONTRACT_FILE" "$CASES_FILE" >/dev/null || fail "cases file is invalid"
jq -e '.type == "object" and .additionalProperties == false and (.required | sort) == (.properties | keys | sort) and (.properties.route.enum == ["direct", "plan", "lean", "audited"]) and (.properties.implementation_authorized.type == "boolean") and (.properties.file_changes_authorized.type == "boolean") and (.properties.authority_action.enum == ["none", "reuse", "create", "link"])' "$SCHEMA_FILE" >/dev/null || fail "decision schema is invalid"
[[ -f "$PROMPT_CONTRACT_FILE" && -f "$CODEX_REFERENCE_FILE" && -f "$CLAUDE_REFERENCE_FILE" ]] || fail "eval prompt or host reference is missing"

if [[ "$LIST_ONLY" -eq 1 ]]; then
  jq -r '.[].id' "$CASES_FILE"
  exit 0
fi

[[ "$PROVIDER" == "codex" || "$PROVIDER" == "claude" ]] || fail "--provider must be codex or claude"
[[ -n "$MODEL" ]] || fail "--model is required"
if [[ "$PROVIDER" == "claude" ]]; then
  [[ "$EFFORT" =~ ^(low|medium|high|xhigh|max)$ ]] || fail "Claude --effort must be low, medium, high, xhigh, or max"
else
  [[ "$EFFORT" =~ ^(none|low|medium|high|xhigh|max)$ ]] || fail "Codex --effort must be none, low, medium, high, xhigh, or max"
fi
[[ -f "$HARNESS_FILE" ]] || fail "harness file does not exist: $HARNESS_FILE"
[[ "$FORCE_OUTPUT" -eq 0 || -n "$OUTPUT_FILE" ]] || fail "--force requires --output"

if [[ -n "$OUTPUT_FILE" ]]; then
  command -v perl >/dev/null || fail "perl is required for safe atomic output publishing"
  [[ "$OUTPUT_FILE" == /* ]] || fail "--output must be an absolute path outside the repository"
  output_dir="$(dirname "$OUTPUT_FILE")"
  [[ -d "$output_dir" ]] || fail "output directory does not exist: $output_dir"
  output_dir="$(cd "$output_dir" && pwd -P)"
  output_name="$(basename "$OUTPUT_FILE")"
  resolved_output="$output_dir/$output_name"
  [[ "$resolved_output" != "$REPO_ROOT" && "$resolved_output" != "$REPO_ROOT/"* ]] || fail "write eval output outside the repository"
  [[ ! -L "$OUTPUT_FILE" ]] || fail "--output must not be a symbolic link"
  if [[ -e "$OUTPUT_FILE" && "$FORCE_OUTPUT" -eq 0 ]]; then
    fail "output already exists; choose another path or pass --force"
  fi
  if [[ -e "$OUTPUT_FILE" && ! -f "$OUTPUT_FILE" ]]; then
    fail "existing output is not a regular file"
  fi
  OUTPUT_FILE="$resolved_output"
fi

if [[ "$PROVIDER" == "codex" ]]; then
  command -v codex >/dev/null || fail "codex CLI is not installed"
  HOST_FILE="$CODEX_REFERENCE_FILE"
else
  command -v claude >/dev/null || fail "claude CLI is not installed"
  HOST_FILE="$CLAUDE_REFERENCE_FILE"
fi
[[ -f "$HOST_FILE" ]] || fail "host reference does not exist: $HOST_FILE"

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-product-eval.XXXXXX")"
cleanup() {
  rm -r "$TEMP_ROOT"
  if [[ -n "$OUTPUT_TEMP" && -e "$OUTPUT_TEMP" ]]; then
    unlink "$OUTPUT_TEMP"
  fi
}
trap cleanup EXIT

cp "$CASES_FILE" "$TEMP_ROOT/cases.json"
cp "$SCHEMA_FILE" "$TEMP_ROOT/decision.schema.json"
cp "$PROMPT_CONTRACT_FILE" "$TEMP_ROOT/routing-prompt.md"
cp "$HARNESS_FILE" "$TEMP_ROOT/workflow-skill.md"
cp "$CODEX_REFERENCE_FILE" "$TEMP_ROOT/codex-reference.md"
cp "$CLAUDE_REFERENCE_FILE" "$TEMP_ROOT/claude-reference.md"

CASES_FILE="$TEMP_ROOT/cases.json"
SCHEMA_FILE="$TEMP_ROOT/decision.schema.json"
PROMPT_CONTRACT_FILE="$TEMP_ROOT/routing-prompt.md"
HARNESS_FILE="$TEMP_ROOT/workflow-skill.md"
CODEX_REFERENCE_FILE="$TEMP_ROOT/codex-reference.md"
CLAUDE_REFERENCE_FILE="$TEMP_ROOT/claude-reference.md"

jq -e -f "$CASE_CONTRACT_FILE" "$CASES_FILE" >/dev/null || fail "snapshotted cases file is invalid"
jq -e '.type == "object" and .additionalProperties == false and (.required | sort) == (.properties | keys | sort)' "$SCHEMA_FILE" >/dev/null || fail "snapshotted decision schema is invalid"

HARNESS_SHA256="$(sha256_file "$HARNESS_FILE")"
CASES_SHA256="$(sha256_file "$CASES_FILE")"
SCHEMA_SHA256="$(sha256_file "$SCHEMA_FILE")"
PROMPT_SHA256="$(sha256_file "$PROMPT_CONTRACT_FILE")"
CODEX_REFERENCE_SHA256="$(sha256_file "$CODEX_REFERENCE_FILE")"
CLAUDE_REFERENCE_SHA256="$(sha256_file "$CLAUDE_REFERENCE_FILE")"

if [[ -n "$CASE_ID" ]]; then
  jq -e --arg id "$CASE_ID" 'any(.[]; .id == $id)' "$CASES_FILE" >/dev/null || fail "unknown case: $CASE_ID"
  CASES_JSON="$(jq -c --arg id "$CASE_ID" '.[] | select(.id == $id)' "$CASES_FILE")"
else
  CASES_JSON="$(jq -c '.[]' "$CASES_FILE")"
fi

if [[ "$PROVIDER" == "codex" ]]; then
  HOST_FILE="$CODEX_REFERENCE_FILE"
else
  HOST_FILE="$CLAUDE_REFERENCE_FILE"
fi

RESULT_TEMP="$TEMP_ROOT/results.jsonl"
if [[ -n "$OUTPUT_FILE" ]]; then
  OUTPUT_TEMP="$(mktemp "$output_dir/.dotagents-product-eval.XXXXXX")"
fi

emit_result() {
  local result="$1"
  if [[ -n "$OUTPUT_FILE" ]]; then
    printf '%s\n' "$result" >> "$OUTPUT_TEMP"
  else
    printf '%s\n' "$result" >> "$RESULT_TEMP"
  fi
}

run_codex() {
  local prompt_file="$1" decision_file="$2" raw_file="$3"
  codex exec \
    --ephemeral \
    --ignore-user-config \
    --ignore-rules \
    --strict-config \
    --disable image_generation \
    --disable shell_tool \
    --disable unified_exec \
    --disable view_image \
    --skip-git-repo-check \
    --cd "$TEMP_ROOT" \
    --sandbox read-only \
    --model "$MODEL" \
    --config 'agents.enabled=false' \
    --config 'apps._default.enabled=false' \
    --config "model_reasoning_effort=\"$EFFORT\"" \
    --config 'web_search="disabled"' \
    --output-schema "$SCHEMA_FILE" \
    --output-last-message "$decision_file" \
    --json - < "$prompt_file" > "$raw_file"
  jq -e . "$decision_file" >/dev/null
}

run_claude() {
  local prompt_file="$1" decision_file="$2" raw_file="$3"
  local schema_json
  schema_json="$(jq -c 'del(. ["$schema"])' "$SCHEMA_FILE")"
  claude --print \
    --model "$MODEL" \
    --effort "$EFFORT" \
    --safe-mode \
    --tools "" \
    --no-session-persistence \
    --output-format json \
    --json-schema "$schema_json" < "$prompt_file" > "$raw_file"
  jq -e '.structured_output // (.result | fromjson)' "$raw_file" > "$decision_file"
}

while IFS= read -r case_json; do
  [[ -n "$case_json" ]] || continue
  case_id="$(jq -r '.id' <<< "$case_json")"
  prompt_file="$TEMP_ROOT/$case_id.prompt"
  decision_file="$TEMP_ROOT/$case_id.decision.json"
  raw_file="$TEMP_ROOT/$case_id.raw"

  {
    cat "$PROMPT_CONTRACT_FILE"
    printf '%s\n\n' '--- SHARED WORKFLOW ---'
    cat "$HARNESS_FILE"
    printf '%s\n\n' '--- ACTIVE HOST REFERENCE ---'
    cat "$HOST_FILE"
    printf '%s\n\n' '--- SCENARIO ---'
    jq '{context, request}' <<< "$case_json"
  } > "$prompt_file"

  started_at="$(date +%s)"
  if [[ "$PROVIDER" == "codex" ]]; then
    run_codex "$prompt_file" "$decision_file" "$raw_file"
    usage_json="$(jq -sc 'map(select(.usage? != null) | .usage) | last // {}' "$raw_file")"
    input_tokens="$(jq -c '.input_tokens // null' <<< "$usage_json")"
    output_tokens="$(jq -c '.output_tokens // null' <<< "$usage_json")"
    reasoning_tokens="$(jq -c '.reasoning_tokens // .output_tokens_details.reasoning_tokens // null' <<< "$usage_json")"
    cache_read_tokens="$(jq -c '.cached_input_tokens // .input_tokens_details.cached_tokens // null' <<< "$usage_json")"
    cache_write_tokens="$(jq -c '.cache_write_input_tokens // .input_tokens_details.cache_write_tokens // null' <<< "$usage_json")"
    cost_usd="null"
  else
    run_claude "$prompt_file" "$decision_file" "$raw_file"
    input_tokens="$(jq -c '.usage.input_tokens // null' "$raw_file")"
    output_tokens="$(jq -c '.usage.output_tokens // null' "$raw_file")"
    reasoning_tokens="$(jq -c '.usage.thinking_tokens // null' "$raw_file")"
    cache_read_tokens="$(jq -c '.usage.cache_read_input_tokens // null' "$raw_file")"
    cache_write_tokens="$(jq -c '.usage.cache_creation_input_tokens // null' "$raw_file")"
    cost_usd="$(jq -c '.total_cost_usd // null' "$raw_file")"
  fi
  finished_at="$(date +%s)"
  latency_ms="$(( (finished_at - started_at) * 1000 ))"

  result="$(jq -cn \
    --arg provider "$PROVIDER" \
    --arg model "$MODEL" \
    --arg effort "$EFFORT" \
    --arg case_id "$case_id" \
    --arg harness_sha256 "$HARNESS_SHA256" \
    --arg cases_sha256 "$CASES_SHA256" \
    --arg schema_sha256 "$SCHEMA_SHA256" \
    --arg prompt_sha256 "$PROMPT_SHA256" \
    --arg codex_reference_sha256 "$CODEX_REFERENCE_SHA256" \
    --arg claude_reference_sha256 "$CLAUDE_REFERENCE_SHA256" \
    --arg adapter_revision "$ADAPTER_REVISION" \
    --slurpfile decision "$decision_file" \
    --argjson input_tokens "$input_tokens" \
    --argjson output_tokens "$output_tokens" \
    --argjson reasoning_tokens "$reasoning_tokens" \
    --argjson cache_read_tokens "$cache_read_tokens" \
    --argjson cache_write_tokens "$cache_write_tokens" \
    --argjson latency_ms "$latency_ms" \
    --argjson cost_usd "$cost_usd" \
    '{provider: $provider, model: $model, effort: $effort, case_id: $case_id, provenance: {adapter_revision: $adapter_revision, harness_sha256: $harness_sha256, cases_sha256: $cases_sha256, schema_sha256: $schema_sha256, prompt_sha256: $prompt_sha256, codex_reference_sha256: $codex_reference_sha256, claude_reference_sha256: $claude_reference_sha256}, decision: $decision[0], usage: {input_tokens: $input_tokens, output_tokens: $output_tokens, reasoning_or_thinking_tokens: $reasoning_tokens, cache_read_tokens: $cache_read_tokens, cache_write_tokens: $cache_write_tokens, latency_ms: $latency_ms, cost_usd: $cost_usd}}')"
  emit_result "$result"
done <<< "$CASES_JSON"

if [[ -n "$OUTPUT_FILE" ]]; then
  if [[ -e "$OUTPUT_FILE" && "$FORCE_OUTPUT" -eq 0 ]]; then
    fail "output appeared during the run; refusing to overwrite it"
  fi
  if [[ "$FORCE_OUTPUT" -eq 1 ]]; then
    perl -e 'rename($ARGV[0], $ARGV[1]) or die "atomic output publish failed: $!\n"' "$OUTPUT_TEMP" "$OUTPUT_FILE"
  else
    perl -e 'link($ARGV[0], $ARGV[1]) or die "exclusive output publish failed: $!\n"; unlink($ARGV[0]) or die "temporary output cleanup failed: $!\n"' "$OUTPUT_TEMP" "$OUTPUT_FILE"
  fi
  OUTPUT_TEMP=""
else
  cat "$RESULT_TEMP"
fi
