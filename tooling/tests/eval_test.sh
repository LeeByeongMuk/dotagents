#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
EVAL_ROOT="$REPO_ROOT/tooling/evals/product-development"

fail() { echo "test failed: $*" >&2; exit 1; }

jq -e -f "$EVAL_ROOT/case-contract.jq" "$EVAL_ROOT/cases.json" >/dev/null || fail "eval cases are invalid"
jq -e '.type == "object" and .additionalProperties == false and (.required | sort) == (.properties | keys | sort) and (.properties.route.enum == ["direct", "plan", "lean"]) and (.properties.implementation_authorized.type == "boolean") and (.properties.file_changes_authorized.type == "boolean") and (.properties.authority_action.enum == ["none", "reuse", "create", "link"])' "$EVAL_ROOT/decision.schema.json" >/dev/null || fail "eval schema is invalid"

if jq '.[0].id = "../../unsafe"' "$EVAL_ROOT/cases.json" | jq -e -f "$EVAL_ROOT/case-contract.jq" >/dev/null; then
  fail "eval case contract accepted an unsafe case id"
fi
if jq '.[0].expected.unused = true' "$EVAL_ROOT/cases.json" | jq -e -f "$EVAL_ROOT/case-contract.jq" >/dev/null; then
  fail "eval case contract accepted an unknown expected field"
fi

CM_ROOT="$REPO_ROOT/tooling/evals/commit-message"
jq -e 'length >= 5 and all(.[]; (.id | test("^[a-z0-9-]+$")) and (.log | length > 0) and (.change | length > 0) and (.expect | has("type") and has("breaking") and has("revert")))' "$CM_ROOT/cases.json" >/dev/null || fail "commit message eval cases are invalid"
jq -e '.additionalProperties == false and (.required == ["message"]) and .properties.message.type == "string"' "$CM_ROOT/message.schema.json" >/dev/null || fail "commit message eval schema is invalid"
grep -Fq -- '--ignore-rules' "$CM_ROOT/run.sh" && grep -Fq -- '--tools ""' "$CM_ROOT/run.sh" || fail "commit message eval must disable host rules and model tools"
grep -Fq 'write eval output outside the repository' "$CM_ROOT/run.sh" && grep -Fq 'output already exists' "$CM_ROOT/run.sh" || fail "commit message eval runner must preserve output safety"
grep -Fq 'entry_sha256' "$CM_ROOT/run.sh" || fail "commit message eval must record entry point provenance"
[[ "$("$CM_ROOT/run.sh" --list | wc -l | tr -d ' ')" == "$(jq length "$CM_ROOT/cases.json")" ]] || fail "commit message eval runner did not list every case"

listed="$($EVAL_ROOT/run.sh --list)"
[[ "$(wc -l <<< "$listed" | tr -d ' ')" == "12" ]] || fail "eval runner did not list every case"

fixture_score="$($EVAL_ROOT/score.sh --require-all \
  "$EVAL_ROOT/fixtures/codex.jsonl" \
  "$EVAL_ROOT/fixtures/claude.jsonl")" || fail "valid cross-host fixtures did not pass"
grep -Fq $'provider\tmodel\teffort\tcase\tresult' <<< "$fixture_score" || fail "eval score output is missing its header"
[[ "$(grep -Fc $'\tTOTAL(12)\tPASS\t' <<< "$fixture_score")" == "2" ]] || fail "eval score output is missing provider totals"

test_root="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-eval-test.XXXXXX")"
trap 'rm -r "$test_root"' EXIT

expect_score_failure() {
  local label="$1"
  shift
  if "$EVAL_ROOT/score.sh" "$@" > "$test_root/$label.out" 2>&1; then
    fail "$label unexpectedly passed"
  fi
}

jq -c 'if .case_id == "plan-only" then .decision.route = "lean" else . end' \
  "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/invalid.jsonl"
expect_score_failure "wrong-route" "$test_root/invalid.jsonl"

jq -c 'if .case_id == "plan-only" then .decision.file_changes_authorized = true else . end' \
  "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/wrong-file-authorization.jsonl"
expect_score_failure "wrong-file-authorization" "$test_root/wrong-file-authorization.jsonl"

jq -c 'if .case_id == "blocked-implementation-decision" then .decision.questions = [] else . end' \
  "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/missing-blocking-question.jsonl"
expect_score_failure "missing-blocking-question" "$test_root/missing-blocking-question.jsonl"

: > "$test_root/empty.jsonl"
expect_score_failure "empty" "$test_root/empty.jsonl"
expect_score_failure "one-provider-require-all" --require-all "$EVAL_ROOT/fixtures/codex.jsonl"

jq -c '.provider = "unknown"' "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/unknown-provider.jsonl"
expect_score_failure "unknown-provider" "$test_root/unknown-provider.jsonl"

jq -c . "$EVAL_ROOT/fixtures/codex.jsonl" "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/duplicate.jsonl"
expect_score_failure "duplicate" "$test_root/duplicate.jsonl"

jq -c 'if .case_id == "plan-only" then .case_id = "missing-case" else . end' \
  "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/unknown-case.jsonl"
expect_score_failure "unknown-case" "$test_root/unknown-case.jsonl"

jq -c 'if .case_id == "plan-only" then .decision.questions = "not-an-array" else . end' \
  "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/malformed-decision.jsonl"
expect_score_failure "malformed-decision" "$test_root/malformed-decision.jsonl"

jq -c 'if .case_id == "routine-implementation" then .decision.deterministic_checks = [""] else . end' \
  "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/empty-check.jsonl"
expect_score_failure "empty-check" "$test_root/empty-check.jsonl"

jq -c 'if .case_id == "routine-implementation" then .decision.deterministic_checks = ["   "] else . end' \
  "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/whitespace-check.jsonl"
expect_score_failure "whitespace-check" "$test_root/whitespace-check.jsonl"

jq -c 'if .case_id == "plan-only" then .decision.acceptance_criteria = ["AC-1"] else . end' \
  "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/bare-ac.jsonl"
expect_score_failure "bare-ac" "$test_root/bare-ac.jsonl"

jq -c 'if .case_id == "plan-only" then .decision.acceptance_criteria = ["AC-01 first", "AC-1 duplicate"] else . end' \
  "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/duplicate-ac.jsonl"
expect_score_failure "duplicate-ac" "$test_root/duplicate-ac.jsonl"

jq -c 'del(.effort)' "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/missing-effort.jsonl"
expect_score_failure "missing-effort" "$test_root/missing-effort.jsonl"

jq -c '.effort = "unbounded"' "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/unknown-effort.jsonl"
expect_score_failure "unknown-effort" "$test_root/unknown-effort.jsonl"

jq -c '.effort = "none"' "$EVAL_ROOT/fixtures/claude.jsonl" > "$test_root/unsupported-claude-effort.jsonl"
expect_score_failure "unsupported-claude-effort" "$test_root/unsupported-claude-effort.jsonl"

jq -c 'if .case_id == "plan-only" then .usage.input_tokens = "many" else . end' \
  "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/malformed-usage.jsonl"
expect_score_failure "malformed-usage" "$test_root/malformed-usage.jsonl"

jq -c 'if .case_id == "plan-only" then .usage.input_tokens = 1.5 else . end' \
  "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/fractional-token-usage.jsonl"
expect_score_failure "fractional-token-usage" "$test_root/fractional-token-usage.jsonl"

jq -c 'if .case_id == "plan-only" then .model = "different-model" else . end' \
  "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/mixed-model.jsonl"
expect_score_failure "mixed-model" "$test_root/mixed-model.jsonl"

jq -c 'if .case_id == "plan-only" then .effort = "high" else . end' \
  "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/mixed-effort.jsonl"
expect_score_failure "mixed-effort" "$test_root/mixed-effort.jsonl"

jq -c 'if .case_id == "plan-only" then .provenance.cases_sha256 = ("0" * 64) else . end' \
  "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/stale-contract.jsonl"
expect_score_failure "stale-contract" "$test_root/stale-contract.jsonl"

sed -n '1p' "$EVAL_ROOT/fixtures/codex.jsonl" > "$test_root/partial-codex.jsonl"
sed -n '1p' "$EVAL_ROOT/fixtures/claude.jsonl" > "$test_root/partial-claude.jsonl"
$EVAL_ROOT/score.sh "$test_root/partial-codex.jsonl" "$test_root/partial-claude.jsonl" >/dev/null || fail "matching partial cross-host results did not pass"

sed -n '2p' "$EVAL_ROOT/fixtures/claude.jsonl" > "$test_root/mismatched-claude.jsonl"
expect_score_failure "mismatched-case-set" "$test_root/partial-codex.jsonl" "$test_root/mismatched-claude.jsonl"

jq -c '.provenance.harness_sha256 = ("f" * 64)' "$test_root/partial-claude.jsonl" > "$test_root/different-harness.jsonl"
expect_score_failure "different-harness" "$test_root/partial-codex.jsonl" "$test_root/different-harness.jsonl"

printf '%s\n' 'preserve-existing-result' > "$test_root/existing.jsonl"
if "$EVAL_ROOT/run.sh" --provider codex --model gpt-5.6-sol --case plan-only --output "$test_root/existing.jsonl" > "$test_root/existing-output.out" 2>&1; then
  fail "eval runner overwrote an existing output without --force"
fi
grep -Fq 'output already exists' "$test_root/existing-output.out" || fail "eval runner reported the wrong existing-output error"
[[ "$(sed -n '1p' "$test_root/existing.jsonl")" == "preserve-existing-result" ]] || fail "eval runner changed an existing output"

if "$EVAL_ROOT/run.sh" --provider codex --model gpt-5.6-sol --case plan-only --output "$EVAL_ROOT/forbidden-result.jsonl" > "$test_root/repo-output.out" 2>&1; then
  fail "eval runner accepted an output path inside the repository"
fi
grep -Fq 'outside the repository' "$test_root/repo-output.out" || fail "eval runner reported the wrong repository-output error"
[[ ! -e "$EVAL_ROOT/forbidden-result.jsonl" ]] || fail "eval runner created output inside the repository"

if "$EVAL_ROOT/run.sh" --provider codex --model gpt-5.6-sol --case plan-only --force > "$test_root/force-without-output.out" 2>&1; then
  fail "eval runner accepted --force without --output"
fi
grep -Fq -- '--force requires --output' "$test_root/force-without-output.out" || fail "eval runner reported the wrong --force error"

if "$EVAL_ROOT/run.sh" --provider claude --model claude-opus-5 --effort none --case plan-only > "$test_root/unsupported-claude-effort.out" 2>&1; then
  fail "eval runner accepted an effort value unsupported by Claude"
fi
grep -Fq 'Claude --effort must be' "$test_root/unsupported-claude-effort.out" || fail "eval runner reported the wrong Claude effort error"

ln -s "$EVAL_ROOT/fixtures/codex.jsonl" "$test_root/result-link.jsonl"
if "$EVAL_ROOT/run.sh" --provider codex --model gpt-5.6-sol --case plan-only --output "$test_root/result-link.jsonl" --force > "$test_root/symlink-output.out" 2>&1; then
  fail "eval runner accepted a symbolic-link output"
fi
grep -Fq 'symbolic link' "$test_root/symlink-output.out" || fail "eval runner reported the wrong symbolic-link error"

mock_bin="$test_root/mock-bin"
mkdir -p "$mock_bin"
cat > "$mock_bin/codex" <<'MOCK_CODEX'
#!/usr/bin/env bash
set -euo pipefail
args=("$@")
has_arg() { local wanted="$1" value; for value in "${args[@]}"; do [[ "$value" == "$wanted" ]] && return 0; done; return 1; }
has_pair() { local first="$1" second="$2" index; for ((index = 0; index + 1 < ${#args[@]}; index++)); do [[ "${args[$index]}" == "$first" && "${args[$((index + 1))]}" == "$second" ]] && return 0; done; return 1; }
has_arg --strict-config && has_pair --disable shell_tool && has_pair --disable unified_exec && has_pair --disable view_image && has_pair --disable image_generation || exit 81
has_pair --config 'agents.enabled=false' && has_pair --config 'apps._default.enabled=false' && has_pair --config 'web_search="disabled"' || exit 82
[[ "${FAKE_CODEX_FAIL:-0}" == "0" ]] || exit 83
if [[ -n "${FAKE_CODEX_READY_FILE:-}" ]]; then
  : > "$FAKE_CODEX_READY_FILE"
  while [[ ! -e "${FAKE_CODEX_RELEASE_FILE:?}" ]]; do sleep 0.01; done
fi
if [[ -n "${FAKE_CODEX_PROMPT_CAPTURE:-}" ]]; then
  while IFS= read -r line; do printf '%s\n' "$line"; done > "$FAKE_CODEX_PROMPT_CAPTURE"
fi
decision_file=""
for ((index = 0; index + 1 < ${#args[@]}; index++)); do
  [[ "${args[$index]}" == "--output-last-message" ]] && decision_file="${args[$((index + 1))]}"
done
[[ -n "$decision_file" ]] || exit 84
printf '%s\n' '{"route":"direct","implementation_authorized":false,"file_changes_authorized":true,"authority_action":"none","questions":[],"subagents":[],"acceptance_criteria":[],"deterministic_checks":["형식 검사"]}' > "$decision_file"
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":101,"output_tokens":41,"reasoning_tokens":9,"cached_input_tokens":21,"cache_write_input_tokens":4}}'
MOCK_CODEX

cat > "$mock_bin/claude" <<'MOCK_CLAUDE'
#!/usr/bin/env bash
set -euo pipefail
args=("$@")
has_arg() { local wanted="$1" value; for value in "${args[@]}"; do [[ "$value" == "$wanted" ]] && return 0; done; return 1; }
has_pair() { local first="$1" second="$2" index; for ((index = 0; index + 1 < ${#args[@]}; index++)); do [[ "${args[$index]}" == "$first" && "${args[$((index + 1))]}" == "$second" ]] && return 0; done; return 1; }
has_arg --safe-mode && has_arg --no-session-persistence && has_pair --tools '' && has_pair --effort medium || exit 91
printf '%s\n' '{"structured_output":{"route":"direct","implementation_authorized":false,"file_changes_authorized":true,"authority_action":"none","questions":[],"subagents":[],"acceptance_criteria":[],"deterministic_checks":["형식 검사"]},"usage":{"input_tokens":11,"output_tokens":42,"thinking_tokens":8,"cache_read_input_tokens":22,"cache_creation_input_tokens":5},"total_cost_usd":0.004}'
MOCK_CLAUDE
chmod +x "$mock_bin/codex" "$mock_bin/claude"

mock_codex_result="$test_root/mock-codex.jsonl"
mock_claude_result="$test_root/mock-claude.jsonl"
PATH="$mock_bin:$PATH" "$EVAL_ROOT/run.sh" --provider codex --model mock-codex --effort medium --case direct-fix --output "$mock_codex_result"
PATH="$mock_bin:$PATH" "$EVAL_ROOT/run.sh" --provider claude --model mock-claude --effort medium --case direct-fix --output "$mock_claude_result"
"$EVAL_ROOT/score.sh" "$mock_codex_result" "$mock_claude_result" >/dev/null || fail "normalized mock adapter results did not pass"
jq -e '.usage.cache_read_tokens == 21 and .usage.cache_write_tokens == 4 and .provenance.adapter_revision == "2"' "$mock_codex_result" >/dev/null || fail "Codex usage or provenance normalization failed"
jq -e '.usage.cache_read_tokens == 22 and .usage.cache_write_tokens == 5 and .usage.cost_usd == 0.004' "$mock_claude_result" >/dev/null || fail "Claude usage normalization failed"

printf '%s\n' 'preserve-after-model-failure' > "$test_root/failure-preserve.jsonl"
if FAKE_CODEX_FAIL=1 PATH="$mock_bin:$PATH" "$EVAL_ROOT/run.sh" --provider codex --model mock-codex --case direct-fix --output "$test_root/failure-preserve.jsonl" --force >/dev/null 2>&1; then
  fail "mocked provider failure unexpectedly succeeded"
fi
[[ "$(sed -n '1p' "$test_root/failure-preserve.jsonl")" == "preserve-after-model-failure" ]] || fail "provider failure replaced the prior result"

printf '%s\n' 'ORIGINAL HARNESS SNAPSHOT' > "$test_root/custom-harness.md"
if command -v sha256sum >/dev/null; then
  original_harness_hash="$(sha256sum "$test_root/custom-harness.md" | awk '{print $1}')"
else
  original_harness_hash="$(shasum -a 256 "$test_root/custom-harness.md" | awk '{print $1}')"
fi
printf '%s\n' 'replace-on-success' > "$test_root/snapshot-result.jsonl"
mkdir "$test_root/race-destination"
FAKE_CODEX_READY_FILE="$test_root/provider-ready" \
FAKE_CODEX_RELEASE_FILE="$test_root/provider-release" \
FAKE_CODEX_PROMPT_CAPTURE="$test_root/captured-prompt" \
PATH="$mock_bin:$PATH" \
  "$EVAL_ROOT/run.sh" --provider codex --model mock-codex --case direct-fix \
  --harness "$test_root/custom-harness.md" --output "$test_root/snapshot-result.jsonl" --force &
snapshot_pid=$!
for _ in {1..500}; do
  [[ -e "$test_root/provider-ready" ]] && break
  sleep 0.01
done
if [[ ! -e "$test_root/provider-ready" ]]; then
  kill "$snapshot_pid" 2>/dev/null || true
  wait "$snapshot_pid" 2>/dev/null || true
  fail "mock provider did not reach the snapshot race checkpoint"
fi
printf '%s\n' 'MUTATED SOURCE HARNESS' > "$test_root/custom-harness.md"
unlink "$test_root/snapshot-result.jsonl"
ln -s "$test_root/race-destination" "$test_root/snapshot-result.jsonl"
: > "$test_root/provider-release"
wait "$snapshot_pid" || fail "snapshotted mock run failed"
grep -Fq 'ORIGINAL HARNESS SNAPSHOT' "$test_root/captured-prompt" || fail "runner did not use the harness snapshot"
if grep -Fq 'MUTATED SOURCE HARNESS' "$test_root/captured-prompt"; then
  fail "runner reread a changed harness during the run"
fi
jq -e --arg hash "$original_harness_hash" '.provenance.harness_sha256 == $hash' "$test_root/snapshot-result.jsonl" >/dev/null || fail "runner recorded the wrong snapshot hash"
[[ -f "$test_root/snapshot-result.jsonl" && ! -L "$test_root/snapshot-result.jsonl" ]] || fail "atomic force publish followed a replaced destination symlink"
[[ -z "$(ls -A "$test_root/race-destination")" ]] || fail "atomic force publish deposited output through a destination symlink"

echo "Cross-host eval tooling passed."
