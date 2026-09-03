#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
failures=0

ok() { echo "ok: $*"; }
bad() { echo "error: $*" >&2; failures=$((failures + 1)); }

required=(
  AGENTS.md README.md LICENSE .gitignore dotagents.toml
  agents/README.md
  agents/rules/communication.md agents/rules/coding.md agents/rules/git.md
  agents/rules/security.md agents/rules/workflow.md agents/rules/documentation.md
  agents/routing/README.md
  agents/workflows/README.md
  agents/workflows/product-development/WORKFLOW.md
  agents/workflows/product-development/workflow.toml
  agents/hooks/README.md
  agents/hooks/commit-message/check.sh
  agents/hooks/commit-message/claude-pre-tool-use.sh
  agents/hooks/commit-message/commit-msg
  agents/skills/README.md
  agents/skills/owned/README.md
  agents/skills/owned/product-development-workflow/SKILL.md
  agents/skills/owned/product-development-workflow/agents/openai.yaml
  agents/skills/owned/product-development-workflow/references/brief-template.md
  agents/skills/owned/product-development-workflow/references/codex.md
  agents/skills/owned/product-development-workflow/references/claude.md
  agents/skills/owned/product-development-workflow/references/model-fit.md
  agents/skills/owned/product-development-workflow/references/stages.md
  agents/skills/owned/product-development-workflow/references/artifacts.md
  agents/skills/owned/dotagents-promote/SKILL.md
  agents/skills/owned/dotagents-promote/agents/openai.yaml
  agents/skills/wrappers/README.md
  agents/prompts/README.md
  agents/profiles/README.md
  agents/integrations/README.md
  agents/adapters/claude/CLAUDE.md agents/adapters/claude/settings.json agents/adapters/codex/AGENTS.md
  agents/adapters/gemini/GEMINI.md agents/registry/README.md
  agents/registry/skills.toml agents/registry/mcp.toml agents/registry/hooks.toml
  agents/registry/plugins.toml agents/registry/sources.lock
  tooling/scripts/install.sh tooling/scripts/uninstall.sh tooling/scripts/check.sh
  tooling/scripts/check-sources.sh
  tooling/scripts/workflow.sh
  agents/templates/generic/AGENTS.md agents/templates/nextjs/AGENTS.md
  agents/templates/context-docs/README.md agents/templates/context-docs/domain-overview.md
  agents/templates/context-docs/interface-contract.md agents/templates/context-docs/integration-map.md
  tooling/tests/install_test.sh tooling/tests/structure_test.sh tooling/tests/workflow_test.sh
  tooling/tests/eval_test.sh
  tooling/tests/model_fit_test.sh
  tooling/tests/sources_test.sh
  tooling/tests/hooks_test.sh
  tooling/evals/product-development/README.md
  tooling/evals/product-development/case-contract.jq
  tooling/evals/product-development/cases.json
  tooling/evals/product-development/decision.schema.json
  tooling/evals/product-development/routing-prompt.md
  tooling/evals/product-development/run.sh
  tooling/evals/product-development/score.sh
  tooling/evals/product-development/fixtures/codex.jsonl
  tooling/evals/product-development/fixtures/claude.jsonl
  tooling/README.md
  tooling/schemas/README.md
  docs/README.md
  docs/decisions/README.md
  docs/designs/product-development-workflow.md
  docs/evals/product-development-workflow-model-behavior.md
  docs/evals/product-development-workflow-model-fit.md
  docs/decisions/0001-living-context-docs.md
  dist/README.md
)
for path in "${required[@]}"; do
  [[ -f "$REPO_ROOT/$path" ]] || bad "missing required file: $path"
done
[[ "$failures" -eq 0 ]] && ok "required files exist"

broken="$(find "$REPO_ROOT" -path "$REPO_ROOT/.git" -prune -o -type l ! -exec test -e {} \; -print)"
if [[ -n "$broken" ]]; then
  bad "broken symbolic link(s) found"
else
  ok "no broken symbolic links"
fi

for script in "$REPO_ROOT"/tooling/scripts/*.sh "$REPO_ROOT"/tooling/tests/*.sh "$REPO_ROOT"/tooling/evals/product-development/*.sh; do
  bash -n "$script" || bad "shell syntax failed: ${script#"$REPO_ROOT/"}"
done
ok "shell syntax"

if "$REPO_ROOT/tooling/tests/structure_test.sh" >/dev/null; then
  ok "repository structure"
else
  bad "repository structure failed"
fi

if "$REPO_ROOT/tooling/tests/workflow_test.sh" >/dev/null; then
  ok "product workflow"
else
  bad "product workflow failed"
fi

if "$REPO_ROOT/tooling/tests/eval_test.sh" >/dev/null; then
  ok "cross-host workflow eval"
else
  bad "cross-host workflow eval failed"
fi

if "$REPO_ROOT/tooling/tests/model_fit_test.sh" >/dev/null; then
  ok "model fit contract"
else
  bad "model fit contract failed"
fi

if "$REPO_ROOT/tooling/tests/hooks_test.sh" >/dev/null; then
  ok "commit message hooks"
else
  bad "commit message hooks failed"
fi

if "$REPO_ROOT/tooling/tests/sources_test.sh" >/dev/null; then
  ok "external source registry"
else
  bad "external source registry failed"
fi

hardcoded="$(rg -l --fixed-strings "$REPO_ROOT" "$REPO_ROOT" -g '!README.md' -g '!tooling/scripts/check.sh' -g '!.git/**' || true)"
if [[ -n "$hardcoded" ]]; then
  bad "repository absolute path is hardcoded outside README"
else
  ok "no repository absolute path hardcoding"
fi

suspicious_files="$(find "$REPO_ROOT" -path "$REPO_ROOT/.git" -prune -o -type f \( -name '.env' -o -name 'auth.json' -o -name 'credentials.json' -o -name 'cookies.json' -o -name '*.pem' -o -name '*.key' -o -name '*.p12' \) -print)"
if [[ -n "$suspicious_files" ]]; then
  bad "suspicious secret-bearing filename(s) found"
else
  ok "no suspicious secret-bearing files"
fi

secret_hits="$(rg -l --hidden -g '!.git/**' -g '!tooling/scripts/check.sh' -g '!README.md' -g '!*.example.*' '(sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)' "$REPO_ROOT" || true)"
if [[ -n "$secret_hits" ]]; then
  bad "possible secret pattern found (values suppressed)"
else
  ok "no likely secret values"
fi

duplicate=0
for adapter in "$REPO_ROOT/agents/adapters/claude/CLAUDE.md" "$REPO_ROOT/agents/adapters/codex/AGENTS.md" "$REPO_ROOT/agents/adapters/gemini/GEMINI.md"; do
  for rule in "$REPO_ROOT"/agents/rules/*.md; do
    first_rule="$(sed -n '3p' "$rule")"
    if [[ -n "$first_rule" ]] && grep -Fq -- "$first_rule" "$adapter"; then
      duplicate=1
    fi
  done
done
if [[ "$duplicate" -eq 1 ]]; then
  bad "common rule text appears copied into a tool adapter"
else
  ok "tool adapters remain thin"
fi

dry_home="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-check.XXXXXX")"
trap 'rm -r "$dry_home"' EXIT
if DOTAGENTS_HOME="$dry_home" XDG_STATE_HOME="$dry_home/state" "$REPO_ROOT/tooling/scripts/install.sh" --dry-run --global >/dev/null; then
  ok "install dry-run"
else
  bad "install dry-run failed"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed." >&2
  exit 1
fi
echo "All checks passed."
