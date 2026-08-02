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
  docs/decisions dist
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

echo "Repository structure passed."
