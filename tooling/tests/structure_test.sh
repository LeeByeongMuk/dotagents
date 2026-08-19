#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"

fail() { echo "test failed: $*" >&2; exit 1; }

required_dirs=(
  agents/rules agents/routing agents/workflows agents/skills/owned
  agents/skills/wrappers agents/prompts agents/hooks agents/profiles
  agents/integrations/skills agents/integrations/mcp
  agents/integrations/plugins agents/integrations/tools
  agents/adapters/claude agents/adapters/codex agents/adapters/gemini
  agents/registry agents/templates tooling/scripts tooling/schemas tooling/tests
  docs/decisions docs/designs dist
)

for path in "${required_dirs[@]}"; do
  [[ -d "$REPO_ROOT/$path" ]] || fail "missing required directory: $path"
done

legacy_root_dirs=(claude codex gemini scripts templates tests)
for path in "${legacy_root_dirs[@]}"; do
  [[ ! -e "$REPO_ROOT/$path" ]] || fail "legacy root directory still exists: $path"
done

for registry in skills.toml mcp.toml hooks.toml plugins.toml; do
  grep -Eq '^schema_version = [0-9]+$' "$REPO_ROOT/agents/registry/$registry" || fail "missing schema version: agents/registry/$registry"
done
grep -Eq '^lock_version = [0-9]+$' "$REPO_ROOT/agents/registry/sources.lock" || fail "missing lock version: agents/registry/sources.lock"

grep -Fq 'source_root = "agents"' "$REPO_ROOT/dotagents.toml" || fail "dotagents source root is not agents"
grep -Fq 'tooling_root = "tooling"' "$REPO_ROOT/dotagents.toml" || fail "dotagents tooling root is not tooling"
grep -Fq 'output_root = "dist"' "$REPO_ROOT/dotagents.toml" || fail "dotagents output root is not dist"

workflow_alias="$REPO_ROOT/agents/skills/product-development-workflow"
[[ -L "$workflow_alias" ]] || fail "workflow discovery alias is not a symbolic link"
[[ "$(readlink "$workflow_alias")" == "owned/product-development-workflow" ]] || fail "workflow discovery alias target is incorrect"
[[ -f "$workflow_alias/SKILL.md" ]] || fail "workflow discovery alias does not expose SKILL.md"

promote_alias="$REPO_ROOT/agents/skills/dotagents-promote"
[[ -L "$promote_alias" ]] || fail "promote discovery alias is not a symbolic link"
[[ "$(readlink "$promote_alias")" == "owned/dotagents-promote" ]] || fail "promote discovery alias target is incorrect"
[[ -f "$promote_alias/SKILL.md" ]] || fail "promote discovery alias does not expose SKILL.md"

english_docs="$(find "$REPO_ROOT" -path "$REPO_ROOT/.git" -prune -o -type f -name '*.en.md' -print)"
[[ -z "$english_docs" ]] || fail "duplicate English documentation must not be committed"

workflow_skill="$REPO_ROOT/agents/skills/owned/product-development-workflow/SKILL.md"
[[ "$(sed -n '1p' "$workflow_skill")" == "---" ]] || fail "workflow skill is missing opening frontmatter"
[[ "$(grep -c '^---$' "$workflow_skill")" -ge 2 ]] || fail "workflow skill is missing closing frontmatter"
grep -Fqx 'name: product-development-workflow' "$workflow_skill" || fail "workflow skill name is invalid"
grep -Eq '^description: .+' "$workflow_skill" || fail "workflow skill description is missing"
grep -Fq 'Brief' "$workflow_skill" || fail "workflow skill must define the lean Brief path"
grep -Fq 'audited' "$workflow_skill" || fail "workflow skill must preserve the audited path"
grep -Fq -- '- `direct`:' "$workflow_skill" && grep -Fq 'normal edit-and-verify path' "$workflow_skill" || fail "workflow skill must keep non-product work on the direct path"
grep -Fq -- '- `lean`:' "$workflow_skill" && grep -Fq 'This is the default' "$workflow_skill" || fail "workflow skill must route product work to lean by default"
grep -Fq -- '- `audited`:' "$workflow_skill" && grep -Fq 'formal evidence is required' "$workflow_skill" || fail "workflow skill must keep audited routing risk-based"
grep -Fq 'model distrust alone' "$workflow_skill" && grep -Fq 'use `lean`' "$workflow_skill" || fail "workflow skill must not escalate from size or model distrust alone"
grep -Fq 'Reuse a current, authoritative project PRD, issue, or specification' "$workflow_skill" || fail "workflow skill must reuse an authoritative product source"
grep -Fq 'before Execute only when they could change the result' "$workflow_skill" && grep -Fq 'not an approval gate' "$workflow_skill" || fail "workflow skill must make pre-execution elicitation conditional"
grep -Fq "project's living-context documentation rule" "$workflow_skill" || fail "workflow skill must require living context document updates"
grep -Fq 'Do not auto-inject similarity-based memories' "$workflow_skill" || fail "workflow skill must reject automatic similarity-memory injection"
grep -Fq 'references/model-fit.md' "$workflow_skill" || fail "workflow skill must route eligible runs to Model Fit guidance"
grep -Fq 'at least two runnable model candidates' "$workflow_skill" || fail "workflow Model Fit trigger must require runnable candidates or an explicit request"
grep -Fq 'Separate the recommendation from execution' "$workflow_skill" || fail "workflow Model Fit must not imply model-switch authority"
grep -Fq 'references/model-verification.md' "$workflow_skill" || fail "workflow skill must route supported models to verification guidance"
grep -Fq 'Do not require a fixed model-generated review pass' "$workflow_skill" || fail "workflow skill must not force a generic review pass"
grep -Fq 'dotagents promotion candidate' "$workflow_skill" || fail "workflow skill must propose promotion candidates at completion"

promote_skill="$REPO_ROOT/agents/skills/owned/dotagents-promote/SKILL.md"
grep -Fq 'Never edit the primary checkout' "$promote_skill" || fail "promote skill must protect the live main checkout"
grep -Fq 'Do not merge into `main` and do not push' "$promote_skill" || fail "promote skill must leave merging to the user"
grep -Fq 'Never run this skill as a hook or as a side effect of another task.' "$promote_skill" || fail "promote skill must forbid background side-effect runs"

workflow_brief="$REPO_ROOT/agents/skills/owned/product-development-workflow/references/brief.md"
[[ -f "$workflow_brief" ]] || fail "workflow living Brief contract is missing"
brief_headings=(
  '## 문제'
  '## 원하는 결과와 성공 신호'
  '## 판단 원칙'
  '## 절대 제약과 비목표'
  '## 수용 조건'
  '## 결정 기록'
  '## 열린 제품 결정'
  '## 실행 체크포인트'
  '## 검증 증거'
  '## 남은 위험'
)
for heading in "${brief_headings[@]}"; do
  grep -Fq "$heading" "$workflow_brief" || fail "workflow Brief is missing required heading: $heading"
done
grep -Fq 'Source priority: reuse a current project PRD, issue, or specification' "$workflow_brief" || fail "workflow Brief must prefer an authoritative existing source"
grep -Fq 'Local fallback: `docs/workflows/<run-id>/brief.md`' "$workflow_brief" || fail "workflow Brief must define the local fallback"
grep -Fq 'Status for a local fallback: `PLANNING`, `EXECUTING`, `VERIFYING`, or `COMPLETE`' "$workflow_brief" || fail "workflow Brief must define every local lifecycle status"
grep -Fq 'Declare the run complete' "$workflow_brief" || fail "workflow Brief must define COMPLETE gates"
grep -Fq 'every acceptance criterion is checked or explicitly rejected by the user;' "$workflow_brief" || fail "workflow Brief must gate completion on acceptance criteria"
grep -Fq 'verification rows contain actual results rather than planned commands;' "$workflow_brief" || fail "workflow Brief must gate completion on actual evidence"
grep -Fq 'remaining risks are explicit;' "$workflow_brief" || fail "workflow Brief must gate completion on explicit remaining risks"
grep -Fq 'the requested delivery action, if any, is complete.' "$workflow_brief" || fail "workflow Brief must gate completion on requested delivery"
grep -Fq 'only when they could change the result' "$workflow_brief" && grep -Fq 'not an approval gate' "$workflow_brief" || fail "workflow Brief must conditionally batch material elicitation"
grep -Fq 'living context documents affected by the change are updated, or the Brief records that none were affected;' "$workflow_brief" || fail "workflow Brief must gate completion on living context documents"
grep -Fq '같은 변경 단위에서 영향받은 컨텍스트 문서를 함께 갱신한다' "$REPO_ROOT/agents/rules/documentation.md" || fail "documentation rule must require update-with-the-change"

workflow_metadata="$REPO_ROOT/agents/skills/owned/product-development-workflow/agents/openai.yaml"
grep -Fq 'display_name: "Product Development Workflow"' "$workflow_metadata" || fail "workflow display metadata is missing"
grep -Eq '^  short_description: ".+"$' "$workflow_metadata" || fail "workflow short description is missing"
grep -Fq '$product-development-workflow' "$workflow_metadata" || fail "workflow default prompt must invoke the skill explicitly"
grep -Fq 'default_prompt:' "$workflow_metadata" && grep -Fq '$product-development-workflow' "$workflow_metadata" && grep -Fq 'verify the result' "$workflow_metadata" || fail "workflow default prompt must preserve Brief-first execution"

model_verification="$REPO_ROOT/agents/skills/owned/product-development-workflow/references/model-verification.md"
[[ -f "$model_verification" ]] || fail "model-specific verification reference is missing"
for model_heading in '## GPT-5.6 Sol' '## Claude Opus 5' '## Claude Fable 5'; do
  grep -Fq "$model_heading" "$model_verification" || fail "model verification guidance is missing: $model_heading"
done
grep -Fiq 'deterministic project checks' "$model_verification" || fail "model verification guidance must preserve deterministic checks"

model_fit="$REPO_ROOT/agents/skills/owned/product-development-workflow/references/model-fit.md"
[[ -f "$model_fit" ]] || fail "Model Fit reference is missing"
for candidate_field in '`provider`' '`model`' '`runnable`' '`source`' '`source_checked_at`' '`role`' '`effort_modes`' '`requirements`' '`economics`' '`eval_evidence`'; do
  grep -Fq "$candidate_field" "$model_fit" || fail "Model Fit candidate inventory is missing: $candidate_field"
done
grep -Fq 'Apply hard filters' "$model_fit" || fail "Model Fit must apply hard constraints before preferences"
grep -Fq 'A representative eval on the current model version and real project prompt outranks provider positioning.' "$model_fit" || fail "Model Fit must prefer representative project evals"
grep -Fq 'Prefer staying in the current context.' "$model_fit" || fail "Model Fit must account for context continuity"
grep -Fq 'Never combine uncertain inputs into a precise weighted score.' "$model_fit" || fail "Model Fit must reject false-precision scoring"
grep -Fq 'separate the recommendation from execution' "$model_fit" || fail "Model Fit must separate advice from host execution"
grep -Fq 'Initial policy coverage is Claude and Codex/OpenAI model families.' "$model_fit" || fail "Model Fit must declare its initial provider coverage"
grep -Fq 'a local candidate may participate later' "$model_fit" || fail "Model Fit must keep a provider-neutral local extension point"
for output_field in 'Decision:' 'Primary:' 'Next-run recommendation:' 'Effort:' 'Optional secondary:' 'Confidence:' 'Hard filters:' 'Evidence:' 'Tradeoff:' 'Execution:' 'Re-evaluate when:'; do
  grep -Fq "$output_field" "$model_fit" || fail "Model Fit result contract is missing: $output_field"
done

model_fit_eval="$REPO_ROOT/docs/evals/product-development-workflow-model-fit.md"
[[ -f "$model_fit_eval" ]] || fail "Model Fit representative scenario eval is missing"
for scenario in 'MF-1' 'MF-2' 'MF-3' 'MF-4' 'MF-5' 'MF-6'; do
  grep -Fq "$scenario" "$model_fit_eval" || fail "Model Fit eval is missing representative scenario: $scenario"
done

workflow_contract="$REPO_ROOT/agents/workflows/product-development/workflow.toml"
grep -Fq 'Audited compatibility contract' "$workflow_contract" || fail "ten-stage contract must be labeled audited"
[[ "$(grep -c '^\[\[stages\]\]$' "$workflow_contract")" -eq 10 ]] || fail "product workflow must define exactly ten stages"
[[ "$(grep -c '^requires_approval = true$' "$workflow_contract")" -eq 10 ]] || fail "every audited workflow stage must require approval"
[[ "$(grep -c '^optional = true$' "$workflow_contract")" -eq 1 ]] || fail "only one product workflow stage may be optional"
grep -A7 '^number = 10$' "$workflow_contract" | grep -Fq 'optional = true' || fail "only stage 10 may be optional"
grep -A7 '^number = 7$' "$workflow_contract" | grep -Fq 'title_ko = "구현 증거"' || fail "audited implementation must not require a subagent by title"
grep -Fq 'Use a subagent only for a sizeable task' "$REPO_ROOT/agents/skills/owned/product-development-workflow/references/stages.md" || fail "audited subagent use must be conditional"

workflow_cli="$REPO_ROOT/tooling/scripts/workflow.sh"
grep -Fq 'Audited compatibility workflow. The default product workflow is Brief -> Execute -> Verify.' "$workflow_cli" || fail "workflow CLI help must identify the audited compatibility path"

skills_registry="$REPO_ROOT/agents/registry/skills.toml"
registry_skill_block() {
  local skill_id="$1"
  awk -v skill_id="$skill_id" '
    BEGIN { RS = "\\[\\[skills\\]\\]" }
    $0 ~ "(^|\\n)id = \\\"" skill_id "\\\"(\\n|$)" { print; exit }
  ' "$skills_registry"
}

while IFS='|' read -r skill_id expected_workflows; do
  skill_block="$(registry_skill_block "$skill_id")"
  [[ -n "$skill_block" ]] || fail "missing skill registry entry: $skill_id"
  grep -Fqx "$expected_workflows" <<< "$skill_block" || fail "unexpected workflow mapping for skill: $skill_id"
done <<'EOF'
mattpocock-grilling|workflows = ["product-development:audited:1"]
gstack-office-hours|workflows = ["product-development:audited:3"]
superpowers-writing-plans|workflows = ["product-development:audited:5"]
gstack-autoplan|workflows = ["product-development:audited:6"]
gstack-review|workflows = ["product-development:verify", "product-development:audited:8"]
gstack-qa|workflows = ["product-development:verify", "product-development:audited:8"]
EOF

for source_id in $(sed -n 's/^source_id = "\([^"]*\)"$/\1/p' "$skills_registry" | sort -u); do
  grep -Fq "id = \"$source_id\"" "$REPO_ROOT/agents/registry/sources.lock" || fail "skill registry references unlocked source: $source_id"
done

skill_count="$(grep -c '^\[\[skills\]\]$' "$skills_registry")"
[[ "$(grep -c '^license = "[^"]\+"$' "$skills_registry")" -eq "$skill_count" ]] || fail "every skill registry entry must declare a license"
[[ "$(grep -c '^enabled_by_default = \(true\|false\)$' "$skills_registry")" -eq "$skill_count" ]] || fail "every skill registry entry must declare default enablement"

echo "Repository structure passed."
