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

while IFS= read -r korean_readme; do
  english_readme="${korean_readme%.md}.en.md"
  [[ -f "$english_readme" ]] || fail "missing English README sibling: ${english_readme#"$REPO_ROOT/"}"
done < <(find "$REPO_ROOT" -path "$REPO_ROOT/.git" -prune -o -type f -name 'README.md' -print)

while IFS= read -r korean_workflow; do
  english_workflow="${korean_workflow%.md}.en.md"
  [[ -f "$english_workflow" ]] || fail "missing English workflow sibling: ${english_workflow#"$REPO_ROOT/"}"
done < <(find "$REPO_ROOT/agents/workflows" -type f -name 'WORKFLOW.md' -print)

while IFS= read -r korean_doc; do
  english_doc="${korean_doc%.md}.en.md"
  [[ -f "$english_doc" ]] || fail "missing English documentation sibling: ${english_doc#"$REPO_ROOT/"}"
done < <(find "$REPO_ROOT/docs" -type f -name '*.md' ! -name '*.en.md' -print)

workflow_skill="$REPO_ROOT/agents/skills/owned/product-development-workflow/SKILL.md"
[[ "$(sed -n '1p' "$workflow_skill")" == "---" ]] || fail "workflow skill is missing opening frontmatter"
[[ "$(grep -c '^---$' "$workflow_skill")" -ge 2 ]] || fail "workflow skill is missing closing frontmatter"
grep -Fqx 'name: product-development-workflow' "$workflow_skill" || fail "workflow skill name is invalid"
grep -Eq '^description: .+' "$workflow_skill" || fail "workflow skill description is missing"

workflow_metadata="$REPO_ROOT/agents/skills/owned/product-development-workflow/agents/openai.yaml"
grep -Fq 'display_name: "Product Development Workflow"' "$workflow_metadata" || fail "workflow display metadata is missing"
grep -Eq '^  short_description: ".+"$' "$workflow_metadata" || fail "workflow short description is missing"
grep -Fq '$product-development-workflow' "$workflow_metadata" || fail "workflow default prompt must invoke the skill explicitly"

workflow_contract="$REPO_ROOT/agents/workflows/product-development/workflow.toml"
[[ "$(grep -c '^\[\[stages\]\]$' "$workflow_contract")" -eq 10 ]] || fail "product workflow must define exactly ten stages"
[[ "$(grep -c '^requires_approval = true$' "$workflow_contract")" -eq 10 ]] || fail "every product workflow stage must require approval"
[[ "$(grep -c '^optional = true$' "$workflow_contract")" -eq 1 ]] || fail "only one product workflow stage may be optional"
grep -A7 '^number = 10$' "$workflow_contract" | grep -Fq 'optional = true' || fail "only stage 10 may be optional"

for source_id in $(sed -n 's/^source_id = "\([^"]*\)"$/\1/p' "$REPO_ROOT/agents/registry/skills.toml" | sort -u); do
  grep -Fq "id = \"$source_id\"" "$REPO_ROOT/agents/registry/sources.lock" || fail "skill registry references unlocked source: $source_id"
done

skill_count="$(grep -c '^\[\[skills\]\]$' "$REPO_ROOT/agents/registry/skills.toml")"
[[ "$(grep -c '^license = "[^"]\+"$' "$REPO_ROOT/agents/registry/skills.toml")" -eq "$skill_count" ]] || fail "every skill registry entry must declare a license"
[[ "$(grep -c '^enabled_by_default = \(true\|false\)$' "$REPO_ROOT/agents/registry/skills.toml")" -eq "$skill_count" ]] || fail "every skill registry entry must declare default enablement"

echo "Repository structure passed."
