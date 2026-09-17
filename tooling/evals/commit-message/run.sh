#!/usr/bin/env bash
# Commit message eval for the composed host entry point.
# Feeds a model the generated entry point (adapter plus common rules) and a staged
# change, then scores the returned message with the same checker the commit hook runs.
# Compare entry point revisions by passing --entry with a different composed file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
CASES_FILE="$SCRIPT_DIR/cases.json"
SCHEMA_FILE="$SCRIPT_DIR/message.schema.json"
PROMPT_FILE="$SCRIPT_DIR/prompt.md"
CHECKER="$REPO_ROOT/agents/hooks/commit-message/check.sh"
ENTRY_FILE=""
PROVIDER=""
MODEL=""
EFFORT="medium"
CASE_ID=""
LABEL="current"
OUTPUT_FILE=""
LIST_ONLY=0

fail() { echo "error: $*" >&2; exit 2; }
usage() {
  echo "Usage: $0 --provider codex|claude --model MODEL [--effort LEVEL] [--entry FILE] [--case ID] [--label NAME] --output FILE" >&2
  echo "       $0 --list" >&2
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
    --entry) ENTRY_FILE="$2"; shift ;;
    --case) CASE_ID="$2"; shift ;;
    --label) LABEL="$2"; shift ;;
    --output) OUTPUT_FILE="$2"; shift ;;
    --list) LIST_ONLY=1 ;;
    -h|--help) usage ;;
    *) fail "unknown option: $1" ;;
  esac
  shift
done

command -v jq >/dev/null || fail "jq is required"
[[ -f "$CASES_FILE" && -f "$SCHEMA_FILE" && -f "$PROMPT_FILE" && -x "$CHECKER" ]] || fail "eval inputs are incomplete"

if [[ "$LIST_ONLY" -eq 1 ]]; then jq -r '.[].id' "$CASES_FILE"; exit 0; fi

[[ "$PROVIDER" == "codex" || "$PROVIDER" == "claude" ]] || usage
[[ -n "$MODEL" && -n "$OUTPUT_FILE" ]] || usage
[[ "$OUTPUT_FILE" == /* ]] || fail "--output must be an absolute path"
[[ "$OUTPUT_FILE" != "$REPO_ROOT"/* ]] || fail "write eval output outside the repository"
[[ ! -e "$OUTPUT_FILE" ]] || fail "output already exists: $OUTPUT_FILE"

if [[ -z "$ENTRY_FILE" ]]; then
  if [[ "$PROVIDER" == "codex" ]]; then ENTRY_FILE="$REPO_ROOT/dist/codex/AGENTS.md"
  else ENTRY_FILE="$REPO_ROOT/dist/claude/CLAUDE.md"; fi
fi
[[ -f "$ENTRY_FILE" ]] || fail "missing entry point: $ENTRY_FILE"

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-commit-eval.XXXXXX")"
trap 'rm -r "$TEMP_ROOT"' EXIT
cp "$ENTRY_FILE" "$TEMP_ROOT/entry.md"
ENTRY_SHA256="$(sha256_file "$TEMP_ROOT/entry.md")"

if [[ -n "$CASE_ID" ]]; then
  jq -e --arg id "$CASE_ID" 'any(.[]; .id == $id)' "$CASES_FILE" >/dev/null || fail "unknown case: $CASE_ID"
  CASES_JSON="$(jq -c --arg id "$CASE_ID" '.[] | select(.id == $id)' "$CASES_FILE")"
else
  CASES_JSON="$(jq -c '.[]' "$CASES_FILE")"
fi

run_codex() {
  codex exec --ephemeral --ignore-user-config --ignore-rules --strict-config \
    --disable image_generation --disable shell_tool --disable unified_exec --disable view_image \
    --skip-git-repo-check --cd "$TEMP_ROOT" --sandbox read-only --model "$MODEL" \
    --config 'agents.enabled=false' --config 'apps._default.enabled=false' \
    --config "model_reasoning_effort=\"$EFFORT\"" --config 'web_search="disabled"' \
    --output-schema "$SCHEMA_FILE" --output-last-message "$2" \
    --json - < "$1" > "$3"
  jq -e . "$2" >/dev/null
}

run_claude() {
  env -u CLAUDECODE claude --print --model "$MODEL" --effort "$EFFORT" --safe-mode --tools "" \
    --no-session-persistence --output-format json \
    --json-schema "$(jq -c 'del(."$schema")' "$SCHEMA_FILE")" < "$1" > "$3"
  jq -e '.structured_output // (.result | fromjson)' "$3" > "$2"
}

while IFS= read -r case_json; do
  [[ -n "$case_json" ]] || continue
  case_id="$(jq -r '.id' <<< "$case_json")"
  prompt_file="$TEMP_ROOT/$case_id.prompt"
  answer_file="$TEMP_ROOT/$case_id.answer.json"
  raw_file="$TEMP_ROOT/$case_id.raw"
  message_file="$TEMP_ROOT/$case_id.msg"
  {
    cat "$PROMPT_FILE"
    printf '\n%s\n\n' '--- PERSONAL DEFAULTS ---'
    cat "$TEMP_ROOT/entry.md"
    printf '\n%s\n\n' '--- RECENT LOG ---'
    jq -r '.log' <<< "$case_json"
    printf '\n%s\n\n' '--- STAGED CHANGE ---'
    jq -r '.change' <<< "$case_json"
    note="$(jq -r '.note // ""' <<< "$case_json")"
    [[ -z "$note" ]] || printf '\n%s\n\n%s\n' '--- NOTE FROM THE AUTHOR ---' "$note"
  } > "$prompt_file"

  started_at="$(date +%s)"
  if [[ "$PROVIDER" == "codex" ]]; then run_codex "$prompt_file" "$answer_file" "$raw_file"
  else run_claude "$prompt_file" "$answer_file" "$raw_file"; fi
  finished_at="$(date +%s)"

  jq -r '.message' "$answer_file" > "$message_file"

  checker_output=""
  if checker_output="$(DOTAGENTS_REPO_DIR="$TEMP_ROOT" "$CHECKER" "$message_file" 2>&1)"; then
    checker_pass=true; checker_reason=""
  else
    checker_pass=false; checker_reason="$(head -1 <<< "$checker_output")"
  fi

  header="$(head -1 "$message_file")"
  actual_type="${header%%[(!:]*}"
  expected_type="$(jq -r '.expect.type' <<< "$case_json")"
  if [[ "|$expected_type|" == *"|$actual_type|"* || "$expected_type" == "$actual_type" ]]; then type_ok=true; else type_ok=false; fi

  expect_breaking="$(jq -r '.expect.breaking' <<< "$case_json")"
  if grep -Fq 'BREAKING CHANGE:' "$message_file" && [[ "$header" == *'!'* ]]; then has_breaking=true; else has_breaking=false; fi
  [[ "$has_breaking" == "$expect_breaking" ]] && breaking_ok=true || breaking_ok=false

  expect_revert="$(jq -r '.expect.revert' <<< "$case_json")"
  if [[ "$header" == revert:* ]] && grep -Eq 'This reverts commit' "$message_file"; then has_revert=true; else has_revert=false; fi
  [[ "$has_revert" == "$expect_revert" ]] && revert_ok=true || revert_ok=false

  if grep -Eqi 'co-authored-by|generated with|🤖' "$message_file"; then trailer_clean=false; else trailer_clean=true; fi

  if [[ "$checker_pass" == true && "$type_ok" == true && "$breaking_ok" == true && "$revert_ok" == true && "$trailer_clean" == true ]]; then
    pass=true
  else
    pass=false
  fi

  jq -cn \
    --arg provider "$PROVIDER" --arg model "$MODEL" --arg effort "$EFFORT" --arg label "$LABEL" \
    --arg case_id "$case_id" --arg entry_sha256 "$ENTRY_SHA256" \
    --arg message "$(cat "$message_file")" --arg checker_reason "$checker_reason" \
    --argjson pass "$pass" --argjson checker_pass "$checker_pass" --argjson type_ok "$type_ok" \
    --argjson breaking_ok "$breaking_ok" --argjson revert_ok "$revert_ok" --argjson trailer_clean "$trailer_clean" \
    --argjson latency_ms "$(( (finished_at - started_at) * 1000 ))" \
    '{provider: $provider, model: $model, effort: $effort, label: $label, case_id: $case_id,
      provenance: {entry_sha256: $entry_sha256},
      pass: $pass,
      checks: {checker: $checker_pass, checker_reason: $checker_reason, type: $type_ok, breaking: $breaking_ok, revert: $revert_ok, no_trailer: $trailer_clean},
      message: $message, latency_ms: $latency_ms}' \
    >> "$OUTPUT_FILE"
  printf '%s [%s] %-22s pass=%-5s checker=%-5s type=%-5s breaking=%-5s revert=%-5s no_trailer=%s\n' \
    "$PROVIDER/$MODEL" "$LABEL" "$case_id" "$pass" "$checker_pass" "$type_ok" "$breaking_ok" "$revert_ok" "$trailer_clean"
done <<< "$CASES_JSON"
