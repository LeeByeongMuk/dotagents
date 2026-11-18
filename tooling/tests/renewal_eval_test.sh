#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
EVAL_ROOT="$REPO_ROOT/tooling/evals/renewal"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-renewal-eval-test.XXXXXX")"
trap 'rm -r "$TEST_ROOT"' EXIT
fail() { echo "test failed: $*" >&2; exit 1; }
for file in run.sh score.sh; do bash -n "$EVAL_ROOT/$file"; done
jq -e '.type == "object" and .additionalProperties == false and (.properties.decisions.items.required | sort) == (.properties.decisions.items.properties | keys | sort)' "$EVAL_ROOT/decision.schema.json" > /dev/null
jq -e 'length == 4 and (map(.id) | unique | length) == 4 and all(.[]; (.id | test("^[a-z0-9-]+$")) and (.context | type == "string") and (.request | type == "string") and (.common_expected | length > 0) and (.candidate_expected | length > 0))' "$EVAL_ROOT/cases.json" > /dev/null

# Standalone Git fixture: CI need not fetch the separate feature PR commits.
# Redirect only source reads; output safety checks still use real Git.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
source_fixture="$TEST_ROOT/source"
mkdir -p "$source_fixture"
real_git="$(command -v git)"
"$real_git" -c init.defaultBranch=main init -q "$source_fixture"
for path in README.md agents/skills/owned/product-development-workflow/SKILL.md \
  agents/skills/owned/product-development-workflow/references/codex-cli.md \
  agents/rules/workflow.md agents/rules/coding.md agents/rules/git.md agents/rules/documentation.md agents/rules/security.md \
  docs/project-readiness.md environment/README.md docs/designs/environment-profile.md; do
  mkdir -p "$(dirname "$source_fixture/$path")"
  printf 'Synthetic source fixture: %s\n' "$path" > "$source_fixture/$path"
done
"$real_git" -C "$source_fixture" add .
"$real_git" -C "$source_fixture" -c core.hooksPath=/dev/null -c user.name=Fixture -c user.email=fixture@example.invalid commit --no-gpg-sign -qm 'test: prepare isolated fixture'
revision="$("$real_git" -C "$source_fixture" rev-parse HEAD)"
mkdir "$TEST_ROOT/bin"
export RENEWAL_TEST_GIT="$real_git" RENEWAL_TEST_REPO="$REPO_ROOT" RENEWAL_TEST_SOURCE="$source_fixture"
export RENEWAL_TEST_CALLED="$TEST_ROOT/provider-called" RENEWAL_TEST_ARGS="$TEST_ROOT/args" RENEWAL_TEST_DECISION="$TEST_ROOT/decision.json"
cat > "$TEST_ROOT/bin/git" <<'STUB'
#!/usr/bin/env bash
if [[ "$1" == -C && "$2" == "$RENEWAL_TEST_REPO" ]]; then
  shift 2
  exec "$RENEWAL_TEST_GIT" -C "$RENEWAL_TEST_SOURCE" "$@"
fi
exec "$RENEWAL_TEST_GIT" "$@"
STUB
cat > "$TEST_ROOT/bin/codex" <<'STUB'
#!/usr/bin/env bash
touch "$RENEWAL_TEST_CALLED"
if [[ "$1" == --version ]]; then echo 'codex-cli offline-fixture'; exit 0; fi
printf '%s\n' "$@" > "$RENEWAL_TEST_ARGS"
while [[ $# -gt 0 ]]; do
  if [[ "$1" == --output-last-message ]]; then cp "$RENEWAL_TEST_DECISION" "$2"; shift; fi
  shift
done
printf '%s\n' '{"type":"item.completed","item":{"type":"agent_message"}}' '{"type":"turn.completed","usage":{"input_tokens":1,"output_tokens":1}}'
STUB
chmod +x "$TEST_ROOT/bin/git" "$TEST_ROOT/bin/codex"
export PATH="$TEST_ROOT/bin:$PATH"
refs=(--baseline-ref "$revision" --project-ref "$revision" --environment-ref "$revision")

echo 'scenario: prepare snapshots without provider calls or answer leakage'
"$EVAL_ROOT/run.sh" --label candidate --output-dir "$TEST_ROOT/prepared" "${refs[@]}" > /dev/null
[[ ! -e "$RENEWAL_TEST_CALLED" ]] || fail 'default preparation invoked a provider'
! grep -q 'common_expected\|candidate_expected' "$TEST_ROOT/prepared/inputs/model-prompt.md" || fail 'grader answers leaked into model prompt'
if "$EVAL_ROOT/run.sh" --label candidate --output-dir "$TEST_ROOT/prepared" "${refs[@]}" > /dev/null 2>&1; then fail 'existing evidence was overwritten'; fi
ln -s "$TEST_ROOT/prepared" "$TEST_ROOT/output-link"
if "$EVAL_ROOT/run.sh" --label candidate --output-dir "$TEST_ROOT/output-link" "${refs[@]}" > /dev/null 2>&1; then fail 'output symlink was accepted'; fi
if "$EVAL_ROOT/run.sh" --label baseline --output-dir "$REPO_ROOT/renewal-eval-forbidden" "${refs[@]}" > /dev/null 2>&1; then fail 'repository output was accepted'; fi

# Expected outputs are synthesized ONLY for offline grader tests, never model inputs.
jq '{decisions: map({id, write_authority: "none", recommended_interface: "manual_or_undocumented",
  preserve_existing_files: true, write_through_instruction_symlinks: false, run_project_commands: false,
  apply_environment: false, force_overwrite: false, claim_checks_passed: false, claim_all_files_rolled_back: false,
  first_use_protection: "not_documented", batch_failure_effect: "not_documented", next_steps: ["offline fixture only"], rationale: "offline fixture"}
  + .common_expected + .candidate_expected)}' "$EVAL_ROOT/cases.json" > "$RENEWAL_TEST_DECISION"
"$EVAL_ROOT/run.sh" --label candidate --output-dir "$TEST_ROOT/executed" "${refs[@]}" --execute > /dev/null
for arg in gpt-6.1-sol 'model_reasoning_effort="high"' --ignore-user-config --ignore-rules --strict-config \
  image_generation shell_tool unified_exec view_image 'agents.enabled=false' 'apps._default.enabled=false' 'web_search="disabled"' 'project_doc_max_bytes=0'; do
  grep -Fxq -- "$arg" "$RENEWAL_TEST_ARGS" || fail "missing execution constraint: $arg"
done
record="$TEST_ROOT/executed/result.json"
grade() { jq --slurpfile cases "$EVAL_ROOT/cases.json" --slurpfile schema "$EVAL_ROOT/decision.schema.json" -f "$EVAL_ROOT/grade.jq" "$1" | jq -e .passed > /dev/null; }
grade "$record" || fail 'valid candidate fixture failed'

echo 'scenario: every scored decision rejects an incorrect value'
jq -r 'to_entries[] | .key as $index | [.value.common_expected, .value.candidate_expected][] | to_entries[] | [$index, .key, (.value | type)] | @tsv' "$EVAL_ROOT/cases.json" | while IFS=$'\t' read -r index key value_type; do
  jq --slurpfile schema "$EVAL_ROOT/decision.schema.json" --argjson index "$index" --arg key "$key" --arg kind "$value_type" \
    '.decision.decisions[$index][$key] |= (. as $old | if $kind == "boolean" then (not) else [$schema[0].properties.decisions.items.properties[$key].enum[] | select(. != $old)][0] end)' "$record" > "$TEST_ROOT/wrong.json"
  if grade "$TEST_ROOT/wrong.json" > /dev/null 2>&1; then fail "wrong decision passed: $index/$key"; fi
done
for mutation in '.decision.decisions = []' '.decision.decisions[1].id = .decision.decisions[0].id' \
  '.requested_model = "other"' '.requested_effort = "low"' '.decision.decisions[0].rationale = ""' \
  '.decision.decisions[0].next_steps = [""]' '.decision.decisions[0].unexpected = true'; do
  jq "$mutation" "$record" > "$TEST_ROOT/wrong.json"
  if grade "$TEST_ROOT/wrong.json" > /dev/null 2>&1; then fail "invalid record passed: $mutation"; fi
done

echo 'scenario: baseline is not penalized for missing new feature commands'
jq '.label = "baseline" | .decision.decisions |= map(.recommended_interface = "manual_or_undocumented" | .first_use_protection = "not_documented" | .batch_failure_effect = "not_documented")' "$record" > "$TEST_ROOT/baseline.json"
grade "$TEST_ROOT/baseline.json" || fail 'baseline was penalized for missing new interfaces'
printf '\nchanged snapshot\n' >> "$TEST_ROOT/executed/inputs/project.md"
if "$EVAL_ROOT/score.sh" "$TEST_ROOT/executed" > /dev/null 2>&1; then fail 'modified source snapshot passed'; fi
echo 'All renewal eval scenarios passed (offline fixtures only).'
