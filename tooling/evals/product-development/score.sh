#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CASES_FILE="$SCRIPT_DIR/cases.json"
CASE_CONTRACT_FILE="$SCRIPT_DIR/case-contract.jq"
SCHEMA_FILE="$SCRIPT_DIR/decision.schema.json"
PROMPT_CONTRACT_FILE="$SCRIPT_DIR/routing-prompt.md"
CODEX_REFERENCE_FILE="$SCRIPT_DIR/../../../agents/skills/owned/product-development-workflow/references/codex.md"
CLAUDE_REFERENCE_FILE="$SCRIPT_DIR/../../../agents/skills/owned/product-development-workflow/references/claude.md"
ADAPTER_REVISION="2"

REQUIRE_ALL=0
if [[ "${1:-}" == "--require-all" ]]; then
  REQUIRE_ALL=1
  shift
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 [--require-all] RESULT.jsonl [RESULT.jsonl ...]" >&2
  exit 2
fi

command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 2; }

fail() {
  echo "error: $*" >&2
  exit 1
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

if ! jq -e -f "$CASE_CONTRACT_FILE" "$CASES_FILE" >/dev/null; then
  fail "cases file does not match the eval contract"
fi

TEMP_RESULTS="$(mktemp "${TMPDIR:-/tmp}/dotagents-product-results.XXXXXX")"
trap 'unlink "$TEMP_RESULTS"' EXIT

for result_file in "$@"; do
  [[ -f "$result_file" ]] || { echo "error: result file does not exist: $result_file" >&2; exit 2; }
  jq -ce . "$result_file" >> "$TEMP_RESULTS" || fail "result file is not valid JSONL: $result_file"
done

[[ -s "$TEMP_RESULTS" ]] || fail "no eval results found"

CASES_SHA256="$(sha256_file "$CASES_FILE")"
SCHEMA_SHA256="$(sha256_file "$SCHEMA_FILE")"
PROMPT_SHA256="$(sha256_file "$PROMPT_CONTRACT_FILE")"
CODEX_REFERENCE_SHA256="$(sha256_file "$CODEX_REFERENCE_FILE")"
CLAUDE_REFERENCE_SHA256="$(sha256_file "$CLAUDE_REFERENCE_FILE")"

if ! jq -se \
  --arg cases_sha256 "$CASES_SHA256" \
  --arg schema_sha256 "$SCHEMA_SHA256" \
  --arg prompt_sha256 "$PROMPT_SHA256" \
  --arg codex_reference_sha256 "$CODEX_REFERENCE_SHA256" \
  --arg claude_reference_sha256 "$CLAUDE_REFERENCE_SHA256" \
  --arg adapter_revision "$ADAPTER_REVISION" '
  def string_array: type == "array" and all(.[]; type == "string" and test("\\S"));
  def exact_result_keys:
    (keys | sort) == (["provider", "model", "effort", "case_id", "provenance", "decision", "usage"] | sort);
  def exact_provenance_keys:
    (keys | sort) == (["adapter_revision", "harness_sha256", "cases_sha256", "schema_sha256", "prompt_sha256", "codex_reference_sha256", "claude_reference_sha256"] | sort);
  def exact_decision_keys:
    (keys | sort) == ([
      "acceptance_criteria",
      "authority_action",
      "deterministic_checks",
      "file_changes_authorized",
      "implementation_authorized",
      "questions",
      "route",
      "subagents"
    ] | sort);
  def exact_usage_keys:
    (keys | sort) == ([
      "cache_read_tokens",
      "cache_write_tokens",
      "cost_usd",
      "input_tokens",
      "latency_ms",
      "output_tokens",
      "reasoning_or_thinking_tokens"
    ] | sort);
  def nullable_nonnegative_integer:
    . == null or (type == "number" and . >= 0 and floor == .);
  def nullable_nonnegative_number:
    . == null or (type == "number" and . >= 0);
  all(.[];
    type == "object" and exact_result_keys and
    (.provider == "codex" or .provider == "claude") and
    (.model | type == "string" and length > 0) and
    ((.provider == "claude" and (.effort | IN("low", "medium", "high", "xhigh", "max"))) or
      (.provider == "codex" and (.effort | IN("none", "low", "medium", "high", "xhigh", "max")))) and
    (.case_id | type == "string" and length > 0) and
    (.provenance | type == "object" and exact_provenance_keys) and
    (.provenance.adapter_revision == $adapter_revision) and
    (.provenance.harness_sha256 | type == "string" and test("^[0-9a-f]{64}$")) and
    (.provenance.cases_sha256 == $cases_sha256) and
    (.provenance.schema_sha256 == $schema_sha256) and
    (.provenance.prompt_sha256 == $prompt_sha256) and
    (.provenance.codex_reference_sha256 == $codex_reference_sha256) and
    (.provenance.claude_reference_sha256 == $claude_reference_sha256) and
    (.decision | type == "object" and exact_decision_keys) and
    (.decision.route | IN("direct", "plan", "lean", "audited")) and
    (.decision.implementation_authorized | type == "boolean") and
    (.decision.file_changes_authorized | type == "boolean") and
    (.decision.authority_action | IN("none", "reuse", "create", "link")) and
    (.decision.questions | string_array) and
    (.decision.subagents | string_array) and
    (.decision.acceptance_criteria | string_array and all(.[]; test("^AC-[0-9]+ +\\S"))) and
    ([.decision.acceptance_criteria[] | capture("^AC-(?<id>[0-9]+)").id | tonumber] | unique | length) == (.decision.acceptance_criteria | length) and
    (.decision.deterministic_checks | string_array) and
    (.usage | type == "object" and exact_usage_keys) and
    all(.usage["input_tokens", "output_tokens", "reasoning_or_thinking_tokens", "cache_read_tokens", "cache_write_tokens", "latency_ms"];
      nullable_nonnegative_integer) and
    (.usage.cost_usd | nullable_nonnegative_number)
  )' "$TEMP_RESULTS" >/dev/null; then
  fail "result does not match the normalized eval contract"
fi

if ! jq -se '([.[].provenance.harness_sha256] | unique | length) == 1' "$TEMP_RESULTS" >/dev/null; then
  fail "results use different workflow harnesses"
fi

if jq -se 'group_by([.provider, .case_id]) | any(.[]; length != 1)' "$TEMP_RESULTS" >/dev/null; then
  fail "duplicate provider/case result"
fi

if ! jq -se 'group_by(.provider) | all(.[]; ([.[].model] | unique | length) == 1 and ([.[].effort] | unique | length) == 1)' "$TEMP_RESULTS" >/dev/null; then
  fail "each provider must use one model and effort across the result set"
fi

if jq -se --slurpfile cases "$CASES_FILE" 'all(.[]; .case_id as $id | any($cases[0][]; .id == $id))' "$TEMP_RESULTS" >/dev/null; then
  :
else
  fail "result references an unknown case"
fi

summary="$(jq -n \
  --slurpfile cases "$CASES_FILE" \
  --slurpfile results "$TEMP_RESULTS" '
  def evaluate($case; $result):
    ($case.expected) as $e |
    [
      {name: "route", pass: ($result.decision.route == $e.route)},
      {name: "implementation_authorized", pass: ($result.decision.implementation_authorized == $e.implementation_authorized)},
      {name: "file_changes_authorized", pass: ($result.decision.file_changes_authorized == $e.file_changes_authorized)},
      {name: "authority_action", pass: ($e.authority_actions | index($result.decision.authority_action) != null)},
      {name: "required_questions", pass: (($result.decision.questions | length) >= $e.min_questions)},
      {name: "questions", pass: (($result.decision.questions | length) <= $e.max_questions)},
      {name: "subagents", pass: (($result.decision.subagents | length) <= $e.max_subagents)},
      {name: "acceptance_criteria", pass: (($result.decision.acceptance_criteria | length) >= $e.min_acceptance_criteria)},
      {name: "deterministic_checks", pass: (($result.decision.deterministic_checks | length) >= $e.min_deterministic_checks)}
    ] as $checks |
    {
      provider: $result.provider,
      model: $result.model,
      effort: $result.effort,
      case_id: $case.id,
      pass: (all($checks[]; .pass)),
      failed_checks: [$checks[] | select(.pass | not) | .name],
      usage: $result.usage
    };
  [
    $results[] as $result |
    ($cases[0][] | select(.id == $result.case_id)) as $case |
    evaluate($case; $result)
  ]')"

jq -r '
  def round_cost: if type == "number" then ((. * 1000000 | round) / 1000000) else . end;
  (["provider", "model", "effort", "case", "result", "failed_checks", "input_tokens", "cache_read_tokens", "cache_write_tokens", "output_tokens", "latency_ms", "cost_usd"] | @tsv),
  (.[] | [.provider, .model, .effort, .case_id, (if .pass then "PASS" else "FAIL" end), (.failed_checks | join(",")), (.usage.input_tokens // "-"), (.usage.cache_read_tokens // "-"), (.usage.cache_write_tokens // "-"), (.usage.output_tokens // "-"), (.usage.latency_ms // "-"), ((.usage.cost_usd // "-") | round_cost)] | @tsv)' <<< "$summary"

expected_cases="$(jq 'length' "$CASES_FILE")"
provider_names="$(jq -r '.[].provider' <<< "$summary" | sort -u | paste -sd, -)"
providers="$(jq -r '.[].provider' <<< "$summary" | sort -u | wc -l | tr -d ' ')"
if [[ "$REQUIRE_ALL" -eq 0 ]]; then
  expected_cases="$(jq -r '.[].case_id' <<< "$summary" | sort -u | wc -l | tr -d ' ')"
elif [[ "$provider_names" != "claude,codex" ]]; then
  fail "--require-all requires complete codex and claude results"
fi
expected_results="$(( expected_cases * providers ))"
actual_results="$(jq 'length' <<< "$summary")"

if [[ "$actual_results" -ne "$expected_results" ]]; then
  fail "expected $expected_results result(s) across $providers provider(s), found $actual_results"
fi

if jq -e 'any(.[]; .pass | not)' <<< "$summary" >/dev/null; then
  exit 1
fi

jq -sr '
  def total_or_dash:
    if length > 0 and all(.[]; type == "number") then add else "-" end;
  def round_cost: if type == "number" then ((. * 1000000 | round) / 1000000) else . end;
  group_by(.provider)[] |
  . as $rows |
  [
    $rows[0].provider,
    $rows[0].model,
    $rows[0].effort,
    "TOTAL(\($rows | length))",
    "PASS",
    "",
    ([$rows[].usage.input_tokens] | total_or_dash),
    ([$rows[].usage.cache_read_tokens] | total_or_dash),
    ([$rows[].usage.cache_write_tokens] | total_or_dash),
    ([$rows[].usage.output_tokens] | total_or_dash),
    ([$rows[].usage.latency_ms] | total_or_dash),
    ([$rows[].usage.cost_usd] | total_or_dash | round_cost)
  ] | @tsv' "$TEMP_RESULTS"

if [[ "$providers" -eq 2 ]]; then
  echo "Cross-host product workflow eval passed: $actual_results result(s), $providers provider(s)."
else
  echo "Product workflow eval passed: $actual_results result(s), $providers provider(s)."
fi
