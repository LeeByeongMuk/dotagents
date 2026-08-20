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
  tooling/evals tooling/evals/product-development
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
grep -Fq -- '- `direct`:' "$workflow_skill" && grep -Fq 'factual lookup' "$workflow_skill" || fail "workflow skill must keep factual non-product work on the direct path"
grep -Fq -- '- `plan`:' "$workflow_skill" && grep -Fq 'stop before Execute' "$workflow_skill" || fail "workflow skill must stop planning-only work before implementation"
grep -Fq -- '- `lean`:' "$workflow_skill" && grep -Fq 'This is the default' "$workflow_skill" || fail "workflow skill must route product work to lean by default"
grep -Fq -- '- `audited`:' "$workflow_skill" && grep -Fq 'formal evidence is required' "$workflow_skill" || fail "workflow skill must keep audited routing risk-based"
grep -Fq 'model distrust alone' "$workflow_skill" && grep -Fq 'according to the user' "$workflow_skill" || fail "workflow skill must route by evidence and user authorization"
grep -Fq 'Words such as “research” or “explore” do not choose the route' "$workflow_skill" && grep -Fq 'A high-risk subject alone does not authorize implementation' "$workflow_skill" || fail "workflow skill must disambiguate research and authorization"
grep -Fq 'Reuse a current, authoritative project PRD, issue, or specification' "$workflow_skill" || fail "workflow skill must reuse an authoritative product source"
grep -Fq 'before Execute only when they could change the result' "$workflow_skill" && grep -Fq 'not an approval gate' "$workflow_skill" || fail "workflow skill must make pre-execution elicitation conditional"
grep -Fq 'Only when no suitable authority exists, read `references/brief-template.md` completely' "$workflow_skill" || fail "workflow skill must load the Brief template conditionally"
grep -Fq 'Use stable `AC-<number>` identifiers' "$workflow_skill" || fail "workflow skill must keep acceptance criteria traceable"
grep -Fq "project's living-context documentation rule" "$workflow_skill" || fail "workflow skill must require living context document updates"
grep -Fq 'Do not auto-inject similarity-based memories' "$workflow_skill" || fail "workflow skill must reject automatic similarity-memory injection"
grep -Fq 'references/codex.md' "$workflow_skill" && grep -Fq 'references/claude.md' "$workflow_skill" || fail "workflow skill must route Codex and Claude to host guidance"
grep -Fq 'Never load an unrelated host reference' "$workflow_skill" || fail "workflow skill must keep host references mutually exclusive"
grep -Fq 'Do not require a fixed model-generated review pass' "$workflow_skill" || fail "workflow skill must not force a generic review pass"
grep -Fq 'dotagents promotion candidate' "$workflow_skill" || fail "workflow skill must propose promotion candidates at completion"

promote_skill="$REPO_ROOT/agents/skills/owned/dotagents-promote/SKILL.md"
grep -Fq 'Never edit the primary checkout' "$promote_skill" || fail "promote skill must protect the live main checkout"
grep -Fq 'Do not merge into `main` and do not push' "$promote_skill" || fail "promote skill must leave merging to the user"
grep -Fq 'Never run this skill as a hook or as a side effect of another task.' "$promote_skill" || fail "promote skill must forbid background side-effect runs"

workflow_brief="$REPO_ROOT/agents/skills/owned/product-development-workflow/references/brief-template.md"
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
grep -Fq 'Read this reference only when the workflow must create a local Brief' "$workflow_brief" || fail "workflow Brief template must be conditional"
grep -Fq 'Source priority: reuse a current project PRD, issue, or specification' "$workflow_brief" || fail "workflow Brief must prefer an authoritative existing source"
grep -Fq 'Local fallback: `docs/workflows/<run-id>/brief.md`' "$workflow_brief" || fail "workflow Brief must define the local fallback"
grep -Fq 'Status: `PLANNING`, `EXECUTING`, `VERIFYING`, or `COMPLETE`' "$workflow_brief" || fail "workflow Brief must define every local lifecycle status"
grep -Fq '`AC-01`' "$workflow_brief" || fail "workflow Brief must assign stable acceptance criterion identifiers"
grep -Fq 'Declare the run complete' "$workflow_brief" || fail "workflow Brief must define COMPLETE gates"
grep -Fq 'every acceptance criterion is checked or explicitly rejected by the user;' "$workflow_brief" || fail "workflow Brief must gate completion on acceptance criteria"
grep -Fq 'verification rows contain actual results rather than planned commands;' "$workflow_brief" || fail "workflow Brief must gate completion on actual evidence"
grep -Fq 'remaining risks are explicit;' "$workflow_brief" || fail "workflow Brief must gate completion on explicit remaining risks"
grep -Fq 'the requested delivery action, if any, is complete.' "$workflow_brief" || fail "workflow Brief must gate completion on requested delivery"
grep -Fq 'Ask only when an answer changes scope, behavior, risk acceptance, or a hard constraint.' "$workflow_brief" || fail "workflow Brief must limit questions to material decisions"
grep -Fq 'living context documents affected by the change are updated, or the Brief records that none were affected;' "$workflow_brief" || fail "workflow Brief must gate completion on living context documents"
grep -Fq '같은 변경 단위에서 영향받은 컨텍스트 문서를 함께 갱신한다' "$REPO_ROOT/agents/rules/documentation.md" || fail "documentation rule must require update-with-the-change"

workflow_metadata="$REPO_ROOT/agents/skills/owned/product-development-workflow/agents/openai.yaml"
grep -Fq 'display_name: "Product Development Workflow"' "$workflow_metadata" || fail "workflow display metadata is missing"
grep -Eq '^  short_description: ".+"$' "$workflow_metadata" || fail "workflow short description is missing"
grep -Fq '$product-development-workflow' "$workflow_metadata" || fail "workflow default prompt must invoke the skill explicitly"
grep -Fq 'default_prompt:' "$workflow_metadata" && grep -Fq '$product-development-workflow' "$workflow_metadata" && grep -Fq 'planning or verified implementation' "$workflow_metadata" || fail "workflow default prompt must preserve plan and implementation routing"

codex_verification="$REPO_ROOT/agents/skills/owned/product-development-workflow/references/codex.md"
claude_verification="$REPO_ROOT/agents/skills/owned/product-development-workflow/references/claude.md"
[[ -f "$codex_verification" && -f "$claude_verification" ]] || fail "host-specific verification references are missing"
grep -Fq '## GPT-5.6 Sol' "$codex_verification" || fail "Codex verification guidance is incomplete"
grep -Fq '## Claude Opus 5' "$claude_verification" && grep -Fq '## Claude Fable 5' "$claude_verification" || fail "Claude verification guidance is incomplete"
grep -Fiq 'shared workflow owns' "$codex_verification" && grep -Fiq 'shared workflow owns' "$claude_verification" || fail "host guidance must preserve the shared workflow contract"

eval_root="$REPO_ROOT/tooling/evals/product-development"
for eval_file in README.md case-contract.jq cases.json decision.schema.json routing-prompt.md run.sh score.sh fixtures/codex.jsonl fixtures/claude.jsonl; do
  [[ -f "$eval_root/$eval_file" ]] || fail "cross-host eval file is missing: $eval_file"
done
jq -e -f "$eval_root/case-contract.jq" "$eval_root/cases.json" >/dev/null || fail "cross-host eval cases violate their input contract"
jq -e 'length == 13 and (map(.id) | index("product-discovery") != null and index("factual-research") != null and index("plan-and-implement") != null and index("high-risk-plan-only") != null and index("durable-plan-update") != null and index("lean-create-authority") != null and index("lean-link-authority") != null and index("blocked-implementation-decision") != null and index("formal-evidence-implementation") != null)' "$eval_root/cases.json" >/dev/null || fail "cross-host eval cases do not cover routing, authority, elicitation, and evidence boundaries"
jq -e '.additionalProperties == false and (.required | sort) == (.properties | keys | sort) and .properties.route.enum == ["direct", "plan", "lean", "audited"] and .properties.file_changes_authorized.type == "boolean"' "$eval_root/decision.schema.json" >/dev/null || fail "cross-host eval schema is inconsistent"
grep -Fq 'model_reasoning_effort' "$eval_root/run.sh" && grep -Fq 'output already exists' "$eval_root/run.sh" || fail "cross-host eval runner must preserve effort and output safety"
grep -Fq -- '--strict-config' "$eval_root/run.sh" && grep -Fq -- '--disable shell_tool' "$eval_root/run.sh" && grep -Fq -- '--tools ""' "$eval_root/run.sh" && grep -Fq 'harness_sha256' "$eval_root/run.sh" || fail "cross-host eval runner must reject config drift, disable model tools, and record provenance"

workflow_contract="$REPO_ROOT/agents/workflows/product-development/workflow.toml"
grep -Fq 'Audited compatibility contract' "$workflow_contract" || fail "ten-stage contract must be labeled audited"
[[ "$(grep -c '^\[\[stages\]\]$' "$workflow_contract")" -eq 10 ]] || fail "product workflow must define exactly ten stages"
[[ "$(grep -c '^requires_approval = true$' "$workflow_contract")" -eq 10 ]] || fail "every audited workflow stage must require approval"
[[ "$(grep -c '^optional = true$' "$workflow_contract")" -eq 1 ]] || fail "only one product workflow stage may be optional"
grep -A7 '^number = 10$' "$workflow_contract" | grep -Fq 'optional = true' || fail "only stage 10 may be optional"
grep -A7 '^number = 7$' "$workflow_contract" | grep -Fq 'title_ko = "구현 증거"' || fail "audited implementation must not require a subagent by title"
grep -Fq 'Use a subagent only for a sizeable task' "$REPO_ROOT/agents/skills/owned/product-development-workflow/references/stages.md" || fail "audited subagent use must be conditional"

workflow_cli="$REPO_ROOT/tooling/scripts/workflow.sh"
grep -Fq 'Audited compatibility workflow. Planning uses Plan; authorized implementation uses Brief -> Execute -> Verify.' "$workflow_cli" || fail "workflow CLI help must identify plan and implementation paths"

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
