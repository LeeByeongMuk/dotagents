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

english_docs="$(find "$REPO_ROOT" -path "$REPO_ROOT/.git" -prune -o -type f -name '*.en.md' -print)"
[[ -z "$english_docs" ]] || fail "duplicate English documentation must not be committed"

workflow_skill="$REPO_ROOT/agents/skills/owned/product-development-workflow/SKILL.md"
[[ "$(sed -n '1p' "$workflow_skill")" == "---" ]] || fail "workflow skill is missing opening frontmatter"
[[ "$(grep -c '^---$' "$workflow_skill")" -ge 2 ]] || fail "workflow skill is missing closing frontmatter"
grep -Fqx 'name: product-development-workflow' "$workflow_skill" || fail "workflow skill name is invalid"
grep -Eq '^description: .+' "$workflow_skill" || fail "workflow skill description is missing"
grep -Fq 'Brief' "$workflow_skill" || fail "workflow skill must define the lean Brief path"
grep -Fq 'audited' "$workflow_skill" || fail "workflow skill must preserve the audited path"
grep -Fqx -- "- \`direct\`: a small edit, isolated bug, explanation, or research-only task. Do not use this workflow; follow the project's normal edit-and-verify path." "$workflow_skill" || fail "workflow skill must keep non-product work on the direct path"
grep -Fqx -- '- `lean`: any product task routed to this skill. This is the default, including substantial features.' "$workflow_skill" || fail "workflow skill must route product work to lean by default"
grep -Fqx -- '- `audited`: use only when the user explicitly requests the ten-stage workflow or when formal evidence is required for compliance, sensitive security boundaries, irreversible data migration, cross-team approval, or a long-lived handoff.' "$workflow_skill" || fail "workflow skill must keep audited routing risk-based"
grep -Fqx 'Do not choose `audited` from file count, task size, or model distrust alone. Explain the concrete risk that requires it. If no such risk exists, use `lean`.' "$workflow_skill" || fail "workflow skill must not escalate from size or model distrust alone"
grep -Fqx '6. Before Execute, present the draft Brief in one batched exchange: the assumptions you made, the alternatives you weighed for consequential choices, and the open product questions only the user can answer. This elicits information the user did not think to volunteer; it is not an approval gate. Wait for an answer only when an open product decision blocks the direction; otherwise continue and fold replies into the Brief.' "$workflow_skill" || fail "workflow skill must present the draft Brief with assumptions and open questions"

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
grep -Fq 'Status: `PLANNING`, `EXECUTING`, `VERIFYING`, or `COMPLETE`' "$workflow_brief" || fail "workflow Brief must define every lifecycle status"
grep -Fq 'Set `Status: COMPLETE` only when:' "$workflow_brief" || fail "workflow Brief must define COMPLETE gates"
grep -Fq 'every acceptance criterion is checked or explicitly rejected by the user;' "$workflow_brief" || fail "workflow Brief must gate completion on acceptance criteria"
grep -Fq 'verification rows contain actual results rather than planned commands;' "$workflow_brief" || fail "workflow Brief must gate completion on actual evidence"
grep -Fq 'remaining risks are explicit;' "$workflow_brief" || fail "workflow Brief must gate completion on explicit remaining risks"
grep -Fq 'the requested delivery action, if any, is complete.' "$workflow_brief" || fail "workflow Brief must gate completion on requested delivery"
grep -Fqx -- '- Present assumptions, weighed alternatives, and open questions together in one exchange before execution begins; do not scatter questions across the run.' "$workflow_brief" || fail "workflow Brief must batch elicitation before execution"

workflow_metadata="$REPO_ROOT/agents/skills/owned/product-development-workflow/agents/openai.yaml"
grep -Fq 'display_name: "Product Development Workflow"' "$workflow_metadata" || fail "workflow display metadata is missing"
grep -Eq '^  short_description: ".+"$' "$workflow_metadata" || fail "workflow short description is missing"
grep -Fq '$product-development-workflow' "$workflow_metadata" || fail "workflow default prompt must invoke the skill explicitly"
grep -Fq 'default_prompt: "Use $product-development-workflow to capture the product Brief, execute autonomously, and verify the result."' "$workflow_metadata" || fail "workflow default prompt must preserve Brief-first execution"

workflow_contract="$REPO_ROOT/agents/workflows/product-development/workflow.toml"
grep -Fq 'Audited compatibility contract' "$workflow_contract" || fail "ten-stage contract must be labeled audited"
[[ "$(grep -c '^\[\[stages\]\]$' "$workflow_contract")" -eq 10 ]] || fail "product workflow must define exactly ten stages"
[[ "$(grep -c '^requires_approval = true$' "$workflow_contract")" -eq 10 ]] || fail "every audited workflow stage must require approval"
[[ "$(grep -c '^optional = true$' "$workflow_contract")" -eq 1 ]] || fail "only one product workflow stage may be optional"
grep -A7 '^number = 10$' "$workflow_contract" | grep -Fq 'optional = true' || fail "only stage 10 may be optional"

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
