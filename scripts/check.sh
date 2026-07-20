#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
failures=0

ok() { echo "ok: $*"; }
bad() { echo "error: $*" >&2; failures=$((failures + 1)); }

required=(
  AGENTS.md README.md LICENSE .gitignore
  agents/rules/communication.md agents/rules/coding.md agents/rules/git.md
  agents/rules/security.md agents/rules/workflow.md
  claude/CLAUDE.md codex/AGENTS.md gemini/GEMINI.md
  scripts/install.sh scripts/uninstall.sh scripts/check.sh
  templates/generic/AGENTS.md templates/nextjs/AGENTS.md tests/install_test.sh
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

for script in "$REPO_ROOT"/scripts/*.sh "$REPO_ROOT"/tests/*.sh; do
  bash -n "$script" || bad "shell syntax failed: ${script#"$REPO_ROOT/"}"
done
ok "shell syntax"

hardcoded="$(rg -l --fixed-strings "$REPO_ROOT" "$REPO_ROOT" -g '!README.md' -g '!scripts/check.sh' -g '!.git/**' || true)"
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

secret_hits="$(rg -l --hidden -g '!.git/**' -g '!scripts/check.sh' -g '!README.md' -g '!*.example.*' '(sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)' "$REPO_ROOT" || true)"
if [[ -n "$secret_hits" ]]; then
  bad "possible secret pattern found (values suppressed)"
else
  ok "no likely secret values"
fi

duplicate=0
for adapter in "$REPO_ROOT/claude/CLAUDE.md" "$REPO_ROOT/codex/AGENTS.md" "$REPO_ROOT/gemini/GEMINI.md"; do
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
if DOTAGENTS_HOME="$dry_home" XDG_STATE_HOME="$dry_home/state" "$REPO_ROOT/scripts/install.sh" --dry-run --global >/dev/null; then
  ok "install dry-run"
else
  bad "install dry-run failed"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed." >&2
  exit 1
fi
echo "All checks passed."
