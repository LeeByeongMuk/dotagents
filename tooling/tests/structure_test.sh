#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"

fail() { echo "test failed: $*" >&2; exit 1; }

# Only directories that hold real assets today. A directory is added together
# with its first asset, so an empty placeholder never becomes required.
required_dirs=(
  agents/rules agents/workflows agents/skills/owned
  agents/hooks agents/profiles agents/integrations
  agents/adapters/claude agents/adapters/codex agents/adapters/gemini
  agents/registry agents/templates tooling/scripts tooling/tests
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

fsd_alias="$REPO_ROOT/agents/skills/fsd-refactor"
[[ -L "$fsd_alias" ]] || fail "FSD discovery alias is not a symbolic link"
[[ "$(readlink "$fsd_alias")" == "owned/fsd-refactor" ]] || fail "FSD discovery alias target is incorrect"
[[ -f "$fsd_alias/SKILL.md" && -f "$fsd_alias/agents/openai.yaml" ]] || fail "FSD discovery alias does not expose skill and metadata"

promote_alias="$REPO_ROOT/agents/skills/dotagents-promote"
[[ -L "$promote_alias" ]] || fail "promote discovery alias is not a symbolic link"
[[ "$(readlink "$promote_alias")" == "owned/dotagents-promote" ]] || fail "promote discovery alias target is incorrect"
[[ -f "$promote_alias/SKILL.md" ]] || fail "promote discovery alias does not expose SKILL.md"

usage_guide_alias="$REPO_ROOT/agents/skills/usage-guide"
[[ -L "$usage_guide_alias" ]] || fail "usage guide discovery alias is not a symbolic link"
[[ "$(readlink "$usage_guide_alias")" == "owned/usage-guide" ]] || fail "usage guide discovery alias target is incorrect"
[[ -f "$usage_guide_alias/SKILL.md" ]] || fail "usage guide discovery alias does not expose SKILL.md"

activity_alias="$REPO_ROOT/agents/skills/repo-activity-review"
[[ -L "$activity_alias" ]] || fail "activity discovery alias is not a symbolic link"
[[ "$(readlink "$activity_alias")" == "owned/repo-activity-review" ]] || fail "activity discovery alias target is incorrect"
[[ -f "$activity_alias/SKILL.md" && -f "$activity_alias/references/recurring.md" ]] || fail "activity discovery alias does not expose skill assets"
activity_skill="$activity_alias/SKILL.md"
[[ "$(sed -n '1p' "$activity_skill")" == "---" ]] || fail "activity skill is missing opening frontmatter"
[[ "$(grep -c '^---$' "$activity_skill")" -ge 2 ]] || fail "activity skill is missing closing frontmatter"
grep -Fqx 'name: repo-activity-review' "$activity_skill" || fail "activity skill name is invalid"
grep -Eq '^description: .+' "$activity_skill" || fail "activity skill description is missing"
activity_metadata="$activity_alias/agents/openai.yaml"
grep -Eq '^  display_name: ".+"$' "$activity_metadata" || fail "activity display metadata is missing"
grep -Eq '^  short_description: ".{25,64}"$' "$activity_metadata" || fail "activity short description is invalid"
grep -Eq '^  default_prompt: ".*\$repo-activity-review.*"$' "$activity_metadata" || fail "activity default prompt must invoke the skill"
if grep -Eq '^  allow_implicit_invocation: false$' "$activity_metadata"; then
  fail "activity skill must remain automatically discoverable"
fi

english_docs="$(find "$REPO_ROOT" -path "$REPO_ROOT/.git" -prune -o -type f -name '*.en.md' -print)"
[[ -z "$english_docs" ]] || fail "duplicate English documentation must not be committed"

workflow_skill="$REPO_ROOT/agents/skills/owned/product-development-workflow/SKILL.md"
[[ "$(sed -n '1p' "$workflow_skill")" == "---" ]] || fail "workflow skill is missing opening frontmatter"
[[ "$(grep -c '^---$' "$workflow_skill")" -ge 2 ]] || fail "workflow skill is missing closing frontmatter"
grep -Fqx 'name: product-development-workflow' "$workflow_skill" || fail "workflow skill name is invalid"
grep -Eq '^description: .+' "$workflow_skill" || fail "workflow skill description is missing"
# Route selection, implementation authorization, authority action and question
# bounds are behavior, not wording: tooling/evals/product-development/cases.json
# measures them across all four routes. Assertions below pin only decisions that
# no eval case observes, so rewording the skill does not break this test.
grep -Fq 'Only when no suitable authority exists, read `references/brief-template.md` completely' "$workflow_skill" || fail "workflow skill must load the Brief template conditionally"
grep -Fq 'Use stable `AC-<number>` identifiers' "$workflow_skill" || fail "workflow skill must keep acceptance criteria traceable"
grep -Fq "project's living-context documentation rule" "$workflow_skill" || fail "workflow skill must require living context document updates"
grep -Fq 'Do not auto-inject similarity-based memories' "$workflow_skill" || fail "workflow skill must reject automatic similarity-memory injection"
grep -Fq 'references/codex-cli.md' "$workflow_skill" && grep -Fq 'references/claude-code.md' "$workflow_skill" || fail "workflow skill must route Codex and Claude to host guidance"
grep -Fq 'Never load an unrelated host reference' "$workflow_skill" || fail "workflow skill must keep host references mutually exclusive"
grep -Fq 'references/model-fit.md' "$workflow_skill" || fail "workflow skill must route eligible runs to Model Fit guidance"
grep -Fq 'only when the user explicitly asks to choose or compare models' "$workflow_skill" || fail "workflow Model Fit must run only on an explicit user request"
grep -Fq 'Separate the recommendation from execution' "$workflow_skill" || fail "workflow Model Fit must not imply model-switch authority"
grep -Fq 'Do not require a fixed model-generated review pass' "$workflow_skill" || fail "workflow skill must not force a generic review pass"
grep -Fq 'dotagents promotion candidate' "$workflow_skill" || fail "workflow skill must propose promotion candidates at completion"

fsd_skill="$REPO_ROOT/agents/skills/owned/fsd-refactor/SKILL.md"
[[ "$(sed -n '1p' "$fsd_skill")" == "---" ]] || fail "FSD skill is missing opening frontmatter"
[[ "$(grep -c '^---$' "$fsd_skill")" -ge 2 ]] || fail "FSD skill is missing closing frontmatter"
grep -Fqx 'name: fsd-refactor' "$fsd_skill" || fail "FSD skill name is invalid"
grep -Eq '^description: .+' "$fsd_skill" || fail "FSD skill description is missing"
fsd_metadata="$REPO_ROOT/agents/skills/owned/fsd-refactor/agents/openai.yaml"
grep -Eq '^  display_name: ".+"$' "$fsd_metadata" || fail "FSD display metadata is missing"
grep -Eq '^  short_description: ".+"$' "$fsd_metadata" || fail "FSD short description is missing"
grep -Eq '^  default_prompt: ".*\$fsd-refactor.*"$' "$fsd_metadata" || fail "FSD default prompt must invoke the skill explicitly"

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
grep -Fq 'living context documents affected by the change are updated, or the Brief records that none were affected;' "$workflow_brief" || fail "workflow Brief must gate completion on living context documents"
grep -Fq '같은 변경 단위에서 영향받은 컨텍스트 문서를 함께 갱신한다' "$REPO_ROOT/agents/rules/documentation.md" || fail "documentation rule must require update-with-the-change"

workflow_metadata="$REPO_ROOT/agents/skills/owned/product-development-workflow/agents/openai.yaml"
grep -Fq 'display_name: "Product Development Workflow"' "$workflow_metadata" || fail "workflow display metadata is missing"
grep -Eq '^  short_description: ".+"$' "$workflow_metadata" || fail "workflow short description is missing"
grep -Fq '$product-development-workflow' "$workflow_metadata" || fail "workflow default prompt must invoke the skill explicitly"
grep -Fq 'default_prompt:' "$workflow_metadata" && grep -Fq '$product-development-workflow' "$workflow_metadata" && grep -Fq 'planning or verified implementation' "$workflow_metadata" || fail "workflow default prompt must preserve plan and implementation routing"

codex_verification="$REPO_ROOT/agents/skills/owned/product-development-workflow/references/codex-cli.md"
claude_verification="$REPO_ROOT/agents/skills/owned/product-development-workflow/references/claude-code.md"
[[ -f "$codex_verification" && -f "$claude_verification" ]] || fail "host-specific verification references are missing"
grep -Fq 'For other Codex models, use the shared risk-triggered review policy' "$codex_verification" || fail "Codex verification guidance must default unlisted models to the shared policy"
grep -Fq 'without its own section below uses the shared policy' "$claude_verification" || fail "Claude verification guidance must default unlisted models to the shared policy"
grep -Fiq 'shared workflow owns' "$codex_verification" && grep -Fiq 'shared workflow owns' "$claude_verification" || fail "host guidance must preserve the shared workflow contract"

eval_root="$REPO_ROOT/tooling/evals/product-development"
for eval_file in README.md case-contract.jq cases.json decision.schema.json routing-prompt.md run.sh score.sh fixtures/codex.jsonl fixtures/claude.jsonl; do
  [[ -f "$eval_root/$eval_file" ]] || fail "cross-host eval file is missing: $eval_file"
done
jq -e -f "$eval_root/case-contract.jq" "$eval_root/cases.json" >/dev/null || fail "cross-host eval cases violate their input contract"
jq -e 'length == 12 and (map(.id) | index("product-discovery") != null and index("factual-research") != null and index("plan-and-implement") != null and index("high-risk-plan-only") != null and index("durable-plan-update") != null and index("lean-create-authority") != null and index("lean-link-authority") != null and index("blocked-implementation-decision") != null and index("formal-evidence-implementation") != null)' "$eval_root/cases.json" >/dev/null || fail "cross-host eval cases do not cover routing, authority, elicitation, and evidence boundaries"
jq -e '.additionalProperties == false and (.required | sort) == (.properties | keys | sort) and .properties.route.enum == ["direct", "plan", "lean"] and .properties.file_changes_authorized.type == "boolean"' "$eval_root/decision.schema.json" >/dev/null || fail "cross-host eval schema is inconsistent"
grep -Fq 'model_reasoning_effort' "$eval_root/run.sh" && grep -Fq 'output already exists' "$eval_root/run.sh" || fail "cross-host eval runner must preserve effort and output safety"
grep -Fq -- '--strict-config' "$eval_root/run.sh" && grep -Fq -- '--disable shell_tool' "$eval_root/run.sh" && grep -Fq -- '--tools ""' "$eval_root/run.sh" && grep -Fq 'harness_sha256' "$eval_root/run.sh" || fail "cross-host eval runner must reject config drift, disable model tools, and record provenance"

# The Model Fit policy and its representative scenarios are owned by
# tooling/tests/model_fit_test.sh. Do not restate those clauses here.

skills_registry="$REPO_ROOT/agents/registry/skills.toml"
registry_skill_block() {
  local skill_id="$1"
  awk -v skill_id="$skill_id" '
    BEGIN { RS = "\\[\\[skills\\]\\]" }
    $0 ~ "(^|\\n)id = \\\"" skill_id "\\\"(\\n|$)" { print; exit }
  ' "$skills_registry"
}

fsd_block="$(registry_skill_block "fsd-refactor")"
[[ -n "$fsd_block" ]] || fail "missing FSD skill registry entry"
for expected in 'kind = "owned"' 'source = "agents/skills/owned/fsd-refactor"' 'license = "MIT"' 'hosts = ["claude", "codex", "gemini"]' 'profiles = ["default", "full"]' 'workflows = []' 'optional = true' 'enabled_by_default = true'; do
  grep -Fqx "$expected" <<< "$fsd_block" || fail "FSD registry contract is invalid: $expected"
done

while IFS='|' read -r skill_id expected_workflows; do
  skill_block="$(registry_skill_block "$skill_id")"
  [[ -n "$skill_block" ]] || fail "missing skill registry entry: $skill_id"
  grep -Fqx "$expected_workflows" <<< "$skill_block" || fail "unexpected workflow mapping for skill: $skill_id"
done <<'EOF'
mattpocock-grilling|workflows = []
gstack-office-hours|workflows = []
superpowers-writing-plans|workflows = []
gstack-autoplan|workflows = []
gstack-review|workflows = ["product-development:verify"]
gstack-qa|workflows = ["product-development:verify"]
EOF

for source_id in $(sed -n 's/^source_id = "\([^"]*\)"$/\1/p' "$skills_registry" | sort -u); do
  grep -Fq "id = \"$source_id\"" "$REPO_ROOT/agents/registry/sources.lock" || fail "skill registry references unlocked source: $source_id"
done

skill_count="$(grep -c '^\[\[skills\]\]$' "$skills_registry")"
[[ "$(grep -c '^license = "[^"]\+"$' "$skills_registry")" -eq "$skill_count" ]] || fail "every skill registry entry must declare a license"
[[ "$(grep -c '^enabled_by_default = \(true\|false\)$' "$skills_registry")" -eq "$skill_count" ]] || fail "every skill registry entry must declare default enablement"

activity_block="$(registry_skill_block repo-activity-review)"
[[ -n "$activity_block" ]] || fail "missing activity skill registry entry"
for expected in \
  'kind = "owned"' \
  'source = "agents/skills/owned/repo-activity-review"' \
  'license = "MIT"' \
  'hosts = ["claude", "codex", "gemini"]' \
  'profiles = ["default", "full"]' \
  'workflows = []' \
  'optional = true' \
  'enabled_by_default = true'; do
  grep -Fqx "$expected" <<< "$activity_block" || fail "invalid activity registry field: $expected"
done

echo "Repository structure passed."
