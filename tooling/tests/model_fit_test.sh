#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
POLICY="$REPO_ROOT/agents/skills/owned/product-development-workflow/references/model-fit.md"
EVAL="$REPO_ROOT/docs/evals/product-development-workflow-model-fit.md"
CODEX_VERIFICATION="$REPO_ROOT/agents/skills/owned/product-development-workflow/references/codex-cli.md"
CLAUDE_VERIFICATION="$REPO_ROOT/agents/skills/owned/product-development-workflow/references/claude-code.md"
README="$REPO_ROOT/README.md"
WORKFLOW="$REPO_ROOT/agents/workflows/product-development/WORKFLOW.md"
DESIGN="$REPO_ROOT/docs/designs/product-development-workflow.md"

fail() { echo "test failed: $*" >&2; exit 1; }

[[ -f "$POLICY" ]] || fail "Model Fit policy is missing"
[[ -f "$EVAL" ]] || fail "Model Fit eval is missing"

policy_contract=(
  'only when the user explicitly asks to choose or compare models.'
  'Skip current-run selection when the user pinned an exact model or project policy already fixes the model and that model passes every non-negotiable constraint.'
  'Treat a user-pinned model as a selection constraint, not permission to override authorization, availability, security, data policy, required tool or modality, context, or budget ceilings.'
  'if the pinned model conflicts, do not execute it, record the hard-filter reason, and stop for user direction.'
  'When only one candidate is runnable and no comparison candidate was explicitly supplied'
  'the sole runnable candidate remains Primary for this run.'
  'Re-run only when the Brief, hard constraints, candidate inventory, or representative eval evidence changes enough to alter the result.'
  'Apply hard filters.'
  'A representative eval on the current model version and real project prompt outranks provider positioning.'
  'Prefer staying in the current context.'
  'Tune before switching when appropriate.'
  'Never combine uncertain inputs into a precise weighted score.'
  'Use efficiency only after the quality bar.'
  'Preserve the host default effort unless current official guidance or project evals justify another supported value.'
  'Use higher effort for measured gains on demanding work'
  'Use lower effort when representative evals retain the acceptance bar'
  'Do not add a second model by default.'
  'An advisor or fresh-context verifier is justified only for a concrete high-risk decision where independence can change the outcome, or for an explicitly authorized representative benchmark.'
  'Starting a paid benchmark, another provider process, or a new remote session requires the same authority as any other external or costly action.'
  'separate the recommendation from execution'
  'Apply it only when the host supports an in-scope model selection without losing required state and current authority permits the action.'
  'Stop for user direction only when the active model cannot meet a hard constraint'
  'a local candidate may participate later'
)
for clause in "${policy_contract[@]}"; do
  grep -Fq "$clause" "$POLICY" || fail "Model Fit policy is missing contract clause: $clause"
done

for output_field in 'Decision:' 'Primary:' 'Next-run recommendation:' 'Effort:' 'Optional secondary:' 'Confidence:' 'Hard filters:' 'Evidence:' 'Tradeoff:' 'Execution:' 'Re-evaluate when:'; do
  grep -Fq "$output_field" "$POLICY" || fail "Model Fit result contract is missing: $output_field"
done

confidence_contract=(
  'Use `high` confidence only when hard constraints or current representative evals decide the result.'
  'Use `medium` for current official role guidance plus a clear task fit.'
  'Use `low` when metadata or workload evidence is incomplete; low confidence cannot justify an automatic cross-provider switch.'
)
for clause in "${confidence_contract[@]}"; do
  grep -Fq "$clause" "$POLICY" || fail "Model Fit confidence contract is missing: $clause"
done

grep -Fq 'Use `stay` when the active model remains Primary' "$POLICY" || fail "stay semantics are missing"
grep -Fq '`switch` only when the host actually applies an authorized current-run change' "$POLICY" || fail "switch semantics are missing"
grep -Fq '`recommendation-only` when a different candidate is advice for a later run' "$POLICY" || fail "recommendation-only semantics are missing"
grep -Fq '`blocked` when no candidate can execute without violating a hard constraint or an unresolved pinned-model conflict' "$POLICY" || fail "blocked semantics are missing"

scenario_expectations=(
  'MF-1|`anthropic/claude-opus-5` 전환|project eval'
  'MF-2|`openai/gpt-5.6-luna` 전환|economics'
  'MF-3|Sol을 hard-filter|다시 묻지 않는다'
  'MF-4|Sonnet 5 유지|문맥 이전 이득이 없음'
  'MF-5|current-run primary는 Sol|next-run recommendation으로 Opus 5'
  'MF-6|`decision = blocked`|`needs_user_input = true`'
)

for expectation in "${scenario_expectations[@]}"; do
  IFS='|' read -r scenario first second <<< "$expectation"
  block="$(awk -v heading="### $scenario:" '
    $0 ~ "^" heading { capture = 1 }
    capture && $0 ~ "^### MF-" && $0 !~ "^" heading { exit }
    capture { print }
  ' "$EVAL")"
  [[ -n "$block" ]] || fail "Model Fit eval scenario is missing: $scenario"
  grep -Fq "$first" <<< "$block" || fail "$scenario is missing expected result: $first"
  grep -Fq "$second" <<< "$block" || fail "$scenario is missing expected rationale: $second"
done

mf2_block="$(awk '
  /^### MF-2:/ { capture = 1 }
  capture && /^### MF-/ && !/^### MF-2:/ { exit }
  capture { print }
' "$EVAL")"
grep -Fq '불필요한 두 번째 모델을 사용하지 않는다.' <<< "$mf2_block" || fail "MF-2 must keep the optional second model empty"

grep -Fq 'Status: `CONTRACT PASS / CROSS-PROVIDER NOT RUN`' "$EVAL" || fail "Model Fit eval status is not explicit"
grep -Fq '구조·계약 검사' "$EVAL" || fail "Model Fit eval must distinguish local contract evidence"
grep -Fq '외부 실행' "$EVAL" || fail "Model Fit eval must disclose cross-provider execution status"

for verification in "$CODEX_VERIFICATION" "$CLAUDE_VERIFICATION"; do
  grep -Fq 'This policy starts after model selection.' "$verification" || fail "host verification must start after Model Fit selection"
  grep -Fq 'A Model Fit recommendation must not be presented as verification evidence.' "$verification" || fail "model recommendation must not count as verification evidence"
done

for doc in "$README" "$WORKFLOW" "$DESIGN"; do
  grep -Fq 'Model Fit' "$doc" || fail "Model Fit is missing from ${doc#$REPO_ROOT/}"
  grep -Eq 'Claude.*Codex/OpenAI|Codex/OpenAI.*Claude' "$doc" || fail "initial Claude and Codex/OpenAI coverage is missing from ${doc#$REPO_ROOT/}"
done
grep -Fq '호스트가 전환을 지원하지 않으면 현재 실행을 계속하고 다음 실행 권고로 기록' "$README" || fail "README must separate recommendation from execution"
grep -Fq '권고는 모델 전환 권한이 아닙니다.' "$WORKFLOW" || fail "workflow guide must separate recommendation from execution"
grep -Fq '모델 권고와 실제 전환은 분리한다.' "$DESIGN" || fail "design must separate recommendation from execution"

echo "Model Fit contract passed."
