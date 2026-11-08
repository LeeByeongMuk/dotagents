#!/usr/bin/env bash
# Check required tools and managed links in an existing global install.
# Diagnostics only: never replace user files or install hooks.
set -euo pipefail

missing=0
hook_issue=0
entry_issue=0

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
if [[ -f "$target_root/.agents/rules/git.md" ]]; then
  installed_agents="$(cd "$target_root/.agents" && pwd -P)"
  installed_repo="$(dirname "$installed_agents")"
  for entry in 'claude/CLAUDE.md' 'codex/AGENTS.md' 'gemini/GEMINI.md'; do
    target="$target_root/.$entry"
    source="$installed_repo/dist/$entry"
    adapter="$installed_agents/adapters/$entry"
    if [[ ! -f "$source" ]]; then
      echo "missing: generated host entry point ($source); run make build in the primary checkout" >&2
    elif [[ -L "$target" && "$target" -ef "$source" ]]; then
      echo "ok: host entry point ($target)"
      continue
    elif [[ ! -e "$target" && ! -L "$target" ]]; then
      echo "missing: host entry point ($target); review the global install dry-run, then reinstall from the primary checkout" >&2
    elif [[ -L "$target" && ! -e "$target" ]]; then
      echo "broken: host entry point ($target); review the global install dry-run, then reinstall from the primary checkout" >&2
    elif [[ -L "$target" && "$target" -ef "$adapter" ]]; then
      echo "stale: host entry point ($target) links the thin adapter without common rules; review the global install dry-run, then reinstall from the primary checkout" >&2
    else
      echo "conflict: host entry point ($target) does not link $source; review the existing file before changing it" >&2
    fi
    entry_issue=1
  done
else
  echo "skip: host entry points (dotagents is not globally installed)"
fi

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
if [[ "$missing" -ne 0 || "$hook_issue" -ne 0 || "$entry_issue" -ne 0 ]]; then
  exit 1
fi
echo "All doctor checks passed."
