#!/usr/bin/env bash
# Model behavior eval for the product-development workflow.
# Measures execution decisions (authority reuse, pre-execution pause, subagents,
# model-generated review) for one host reference on one model. Scores nothing;
# compare results across host reference variants and models by hand or with jq.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
SKILL_DIR="$REPO_ROOT/agents/skills/owned/product-development-workflow"
BEHAVIOR_DIR="$SCRIPT_DIR/behavior"
SCENARIOS_FILE="$BEHAVIOR_DIR/scenarios.json"
SCHEMA_FILE="$BEHAVIOR_DIR/decision.schema.json"
PROMPT_FILE="$BEHAVIOR_DIR/prompt.md"
HARNESS_FILE="$SKILL_DIR/SKILL.md"
HOST_FILE=""
PROVIDER=""
MODEL=""
EFFORT="medium"
SCENARIO_ID=""
LABEL="current"
OUTPUT_FILE=""

fail() { echo "error: $*" >&2; exit 1; }
usage() {
  echo "Usage: $0 --provider codex|claude --model MODEL [--effort LEVEL] [--host-reference FILE] [--harness FILE] [--scenario ID] [--label NAME] --output FILE" >&2
  exit 1
}

sha256_file() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null; then shasum -a 256 "$1" | awk '{print $1}'
  else fail "sha256sum or shasum is required"; fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) PROVIDER="$2"; shift ;;
    --model) MODEL="$2"; shift ;;
    --effort) EFFORT="$2"; shift ;;
    --host-reference) HOST_FILE="$2"; shift ;;
    --harness) HARNESS_FILE="$2"; shift ;;
    --scenario) SCENARIO_ID="$2"; shift ;;
    --label) LABEL="$2"; shift ;;
    --output) OUTPUT_FILE="$2"; shift ;;
    -h|--help) usage ;;
    *) fail "unknown argument: $1" ;;
  esac
  shift
done

command -v jq >/dev/null || fail "jq is required"
[[ "$PROVIDER" == "codex" || "$PROVIDER" == "claude" ]] || usage
[[ -n "$MODEL" && -n "$OUTPUT_FILE" ]] || usage
[[ "$OUTPUT_FILE" == /* ]] || fail "--output must be an absolute path outside the repository"
[[ "$OUTPUT_FILE" != "$REPO_ROOT"/* ]] || fail "write eval output outside the repository"
if [[ "$PROVIDER" == "claude" ]]; then
  [[ "$EFFORT" =~ ^(low|medium|high|xhigh|max)$ ]] || fail "Claude --effort must be low, medium, high, xhigh, or max"
  command -v claude >/dev/null || fail "claude CLI is not installed"
  [[ -n "$HOST_FILE" ]] || HOST_FILE="$SKILL_DIR/references/claude-code.md"
else
  [[ "$EFFORT" =~ ^(none|low|medium|high|xhigh|max)$ ]] || fail "Codex --effort must be none, low, medium, high, xhigh, or max"
  command -v codex >/dev/null || fail "codex CLI is not installed"
  [[ -n "$HOST_FILE" ]] || HOST_FILE="$SKILL_DIR/references/codex-cli.md"
fi
for f in "$SCENARIOS_FILE" "$SCHEMA_FILE" "$PROMPT_FILE" "$HARNESS_FILE" "$HOST_FILE"; do
  [[ -f "$f" ]] || fail "missing input: $f"
done

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-behavior-eval.XXXXXX")"
trap 'rm -r "$TEMP_ROOT"' EXIT
cp "$HARNESS_FILE" "$TEMP_ROOT/workflow-skill.md"
cp "$HOST_FILE" "$TEMP_ROOT/host-reference.md"
HARNESS_SHA256="$(sha256_file "$TEMP_ROOT/workflow-skill.md")"
HOST_SHA256="$(sha256_file "$TEMP_ROOT/host-reference.md")"

if [[ -n "$SCENARIO_ID" ]]; then
  jq -e --arg id "$SCENARIO_ID" 'any(.[]; .id == $id)' "$SCENARIOS_FILE" >/dev/null || fail "unknown scenario: $SCENARIO_ID"
  SCENARIOS_JSON="$(jq -c --arg id "$SCENARIO_ID" '.[] | select(.id == $id)' "$SCENARIOS_FILE")"
else
  SCENARIOS_JSON="$(jq -c '.[]' "$SCENARIOS_FILE")"
fi

run_codex() {
  local prompt_file="$1" decision_file="$2" raw_file="$3"
  codex exec --ephemeral --ignore-user-config --ignore-rules --strict-config \
    --disable image_generation --disable shell_tool --disable unified_exec --disable view_image \
    --skip-git-repo-check --cd "$TEMP_ROOT" --sandbox read-only --model "$MODEL" \
    --config 'agents.enabled=false' --config 'apps._default.enabled=false' \
    --config "model_reasoning_effort=\"$EFFORT\"" --config 'web_search="disabled"' \
    --output-schema "$SCHEMA_FILE" --output-last-message "$decision_file" \
    --json - < "$prompt_file" > "$raw_file"
  jq -e . "$decision_file" >/dev/null
}

run_claude() {
  local prompt_file="$1" decision_file="$2" raw_file="$3"
  env -u CLAUDECODE claude --print --model "$MODEL" --effort "$EFFORT" --safe-mode --tools "" \
    --no-session-persistence --output-format json --json-schema "$(jq -c . "$SCHEMA_FILE")" \
    < "$prompt_file" > "$raw_file"
  jq -e '.structured_output // (.result | fromjson)' "$raw_file" > "$decision_file"
}

while IFS= read -r scenario_json; do
  [[ -n "$scenario_json" ]] || continue
  scenario_id="$(jq -r '.id' <<< "$scenario_json")"
  prompt_file="$TEMP_ROOT/$scenario_id.prompt"
  decision_file="$TEMP_ROOT/$scenario_id.decision.json"
  raw_file="$TEMP_ROOT/$scenario_id.raw"
  {
    cat "$PROMPT_FILE"
    printf '\n%s\n\n' '--- SHARED WORKFLOW ---'
    cat "$TEMP_ROOT/workflow-skill.md"
    printf '\n%s\n\n' '--- ACTIVE HOST REFERENCE ---'
    cat "$TEMP_ROOT/host-reference.md"
    printf '\n%s\n\n' '--- SCENARIO ---'
    jq '{context, request}' <<< "$scenario_json"
  } > "$prompt_file"

  started_at="$(date +%s)"
  if [[ "$PROVIDER" == "codex" ]]; then
    run_codex "$prompt_file" "$decision_file" "$raw_file"
    usage_json="$(jq -sc 'map(select(.usage? != null) | .usage) | last // {}' "$raw_file")"
    input_tokens="$(jq -c '.input_tokens // null' <<< "$usage_json")"
    output_tokens="$(jq -c '.output_tokens // null' <<< "$usage_json")"
    reasoning_tokens="$(jq -c '.reasoning_tokens // .output_tokens_details.reasoning_tokens // null' <<< "$usage_json")"
    cache_read_tokens="$(jq -c '.cached_input_tokens // .input_tokens_details.cached_tokens // null' <<< "$usage_json")"
    cost_usd="null"
  else
    run_claude "$prompt_file" "$decision_file" "$raw_file"
    input_tokens="$(jq -c '.usage.input_tokens // null' "$raw_file")"
    output_tokens="$(jq -c '.usage.output_tokens // null' "$raw_file")"
    reasoning_tokens="$(jq -c '.usage.thinking_tokens // null' "$raw_file")"
    cache_read_tokens="$(jq -c '.usage.cache_read_input_tokens // null' "$raw_file")"
    cost_usd="$(jq -c '.total_cost_usd // null' "$raw_file")"
  fi
  finished_at="$(date +%s)"

  jq -cn \
    --arg provider "$PROVIDER" --arg model "$MODEL" --arg effort "$EFFORT" \
    --arg label "$LABEL" --arg scenario_id "$scenario_id" \
    --arg harness_sha256 "$HARNESS_SHA256" --arg host_sha256 "$HOST_SHA256" \
    --argjson decision "$(cat "$decision_file")" \
    --argjson input_tokens "$input_tokens" --argjson output_tokens "$output_tokens" \
    --argjson reasoning_tokens "$reasoning_tokens" --argjson cache_read_tokens "$cache_read_tokens" --argjson cost_usd "$cost_usd" \
    --argjson latency_ms "$(( (finished_at - started_at) * 1000 ))" \
    '{provider: $provider, model: $model, effort: $effort, label: $label, scenario_id: $scenario_id,
      provenance: {harness_sha256: $harness_sha256, host_reference_sha256: $host_sha256},
      decision: $decision,
      usage: {input_tokens: $input_tokens, cache_read_tokens: $cache_read_tokens, output_tokens: $output_tokens, reasoning_or_thinking_tokens: $reasoning_tokens, latency_ms: $latency_ms, cost_usd: $cost_usd}}' \
    >> "$OUTPUT_FILE"
  echo "$PROVIDER/$MODEL/$EFFORT [$LABEL] $scenario_id: $(jq -c '{a: .authority_action, pause: .pre_execution_pause, sub: (.subagents | length), review: .model_generated_review}' "$decision_file")"
done <<< "$SCENARIOS_JSON"
