#!/usr/bin/env bash
# Check required tools and managed links in an existing global install.
# Diagnostics only: never replace user files or install hooks.
set -euo pipefail

missing=0
link_issue=0
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
agents_target="$target_root/.agents"
state_root="${XDG_STATE_HOME:-$target_root/.local/state}"
manifest="$state_root/dotagents/install.tsv"
recorded_agents=""
if [[ -f "$manifest" ]]; then
  recorded_agents="$(awk -F '\t' -v target="$agents_target" '$1 == target { print $2; exit }' "$manifest")"
fi

installed_repo=""
if [[ -n "$recorded_agents" ]] && ! [[ -L "$agents_target" && "$agents_target" -ef "$recorded_agents" ]]; then
  if [[ -L "$agents_target" && ! -e "$agents_target" ]]; then
    echo "broken: managed .agents link ($agents_target); review the global install dry-run, then reinstall from the primary checkout" >&2
  elif [[ ! -e "$agents_target" && ! -L "$agents_target" ]]; then
    echo "missing: managed .agents link ($agents_target); review the global install dry-run, then reinstall from the primary checkout" >&2
  else
    echo "conflict: managed .agents link ($agents_target) does not link $recorded_agents; review the existing path before changing it" >&2
  fi
  link_issue=1
elif [[ -f "$agents_target/rules/git.md" ]]; then
  installed_agents="$(cd "$target_root/.agents" && pwd -P)"
  installed_repo="$(dirname "$installed_agents")"
elif [[ -n "$recorded_agents" ]]; then
  echo "missing: dotagents source rules ($agents_target/rules/git.md); restore the source checkout before reinstalling" >&2
  link_issue=1
fi

check_link() {
  local target="$1" source="$2" label="$3"
  local fix="${4:-review the global install dry-run, then reinstall from the primary checkout}"
  # A missing source comes first: the link to it dangles, and a reinstall
  # would only recreate the same dangling link.
  if [[ ! -e "$source" ]]; then
    echo "missing: $label source ($source); restore the source checkout before reinstalling" >&2
  elif [[ -L "$target" && "$target" -ef "$source" ]]; then
    echo "ok: $label"
    return
  elif [[ ! -e "$target" && ! -L "$target" ]]; then
    echo "missing: $label ($target); $fix" >&2
  elif [[ -L "$target" && ! -e "$target" ]]; then
    echo "broken: $label ($target); $fix" >&2
  else
    echo "conflict: $label ($target) does not link $source; review the existing path before changing it" >&2
  fi
  link_issue=1
}

if [[ -n "$installed_repo" ]]; then
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

  check_link "$target_root/.codex/hooks.json" "$installed_agents/adapters/codex/hooks.json" "Codex commit hook link"
  check_link "$target_root/.claude/settings.json" "$installed_agents/adapters/claude/settings.json" "Claude settings link"
  for skill in product-development-workflow dotagents-promote usage-guide; do
    check_link "$target_root/.claude/skills/$skill" "$installed_agents/skills/owned/$skill" "Claude skill link ($skill)"
    # The alias is a tracked link inside the source checkout; the installer
    # does not create it, so a reinstall cannot bring it back.
    check_link "$installed_agents/skills/$skill" "$installed_agents/skills/owned/$skill" "shared skill alias ($skill)" "restore the alias in the source checkout"
  done
  echo "note: link checks do not verify host loading or execution; review and trust Codex hooks with /hooks; trust is not checked here"
elif [[ "$link_issue" -ne 0 ]]; then
  echo "skip: host and skill links (repair the managed .agents link or source first)"
else
  echo "skip: host entry points (dotagents is not globally installed)"
  echo "skip: Codex commit hook link (dotagents is not globally installed)"
fi

if [[ "$missing" -ne 0 ]]; then
  echo >&2
  echo "Install the missing tools, then rerun. On macOS: make deps (Homebrew). On Debian/Ubuntu: sudo apt install git jq ripgrep gh" >&2
fi
if [[ "$missing" -ne 0 || "$link_issue" -ne 0 || "$entry_issue" -ne 0 ]]; then
  exit 1
fi
echo "All doctor checks passed."
