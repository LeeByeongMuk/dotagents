#!/usr/bin/env bash
# Check required tools and the Codex hook link in an existing global install.
# Exit 1 for missing required tools or an inconsistent managed hook link.
set -euo pipefail

missing=0
hook_issue=0

check() {
  local kind="$1" name="$2" purpose="$3"
  if command -v "$name" >/dev/null 2>&1; then
    echo "ok: $name ($purpose)"
  elif [[ "$kind" == "required" ]]; then
    echo "missing: $name ($purpose)" >&2
    missing=1
  else
    echo "optional: $name is not installed ($purpose)"
  fi
}

check required git   "install manifest, hooks, repository checks"
check required bash  "all tooling scripts"
check required jq    "commit hook input, eval reports"
check required rg    "secret and hardcoded path scan in check.sh"
check optional gh    "check-sources.sh and pull requests"
check optional shasum "workflow state checksums (sha256sum also works)"

target_root="${DOTAGENTS_HOME:-$HOME}"
hook_source="$target_root/.agents/adapters/codex/hooks.json"
hook_target="$target_root/.codex/hooks.json"
if [[ -f "$hook_source" && -f "$target_root/.agents/rules/git.md" ]]; then
  if [[ "$hook_target" -ef "$hook_source" ]]; then
    echo "ok: Codex commit hook link"
    echo "note: review and trust new or changed hooks in Codex with /hooks; trust is not checked here"
  elif [[ ! -e "$hook_target" && ! -L "$hook_target" ]]; then
    echo "missing: Codex commit hook link ($hook_target); review the global install dry-run, then reinstall from the primary checkout" >&2
    hook_issue=1
  elif [[ -L "$hook_target" && ! -e "$hook_target" ]]; then
    echo "broken: Codex commit hook link ($hook_target); review the global install dry-run, then reinstall from the primary checkout" >&2
    hook_issue=1
  else
    echo "conflict: Codex hooks ($hook_target) do not point to the installed dotagents source; review the existing hooks before changing them" >&2
    hook_issue=1
  fi
else
  echo "skip: Codex commit hook link (dotagents is not globally installed)"
fi

if [[ "$missing" -ne 0 ]]; then
  echo >&2
  echo "Install the missing tools, then rerun. On macOS: make deps (Homebrew). On Debian/Ubuntu: sudo apt install git jq ripgrep gh" >&2
fi
if [[ "$missing" -ne 0 || "$hook_issue" -ne 0 ]]; then
  exit 1
fi
echo "All doctor checks passed."
