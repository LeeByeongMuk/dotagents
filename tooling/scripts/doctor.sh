#!/usr/bin/env bash
# Check required tools and managed links in an existing global install.
# Diagnostics only: never replace user files or install hooks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/lib/owned-skills.sh"
source "$SCRIPT_DIR/lib/install-layout.sh"

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
installed_repo=""
if ! read_install_layout "$manifest" "$target_root"; then
  echo "invalid: installation metadata; restore the managed metadata/ledger before reinstalling" >&2
  link_issue=1
elif [[ "$recorded_layout" == managed ]]; then
  installed_agents="$recorded_agents"
  if [[ -f "$installed_agents/rules/git.md" ]]; then
    installed_repo="$(dirname "$installed_agents")"
  else
    echo "missing: dotagents source rules ($installed_agents/rules/git.md); restore the recorded source checkout" >&2
    link_issue=1
  fi
else
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
    # Only the record says an install exists here, so name it: after a partial
    # uninstall the leftover row is the whole reason for this error.
    echo "note: this install is recorded in $manifest" >&2
    link_issue=1
  elif [[ -L "$agents_target" && -f "$agents_target/rules/git.md" ]]; then
    installed_agents="$(cd "$target_root/.agents" && pwd -P)"
    installed_repo="$(dirname "$installed_agents")"
  elif [[ -n "$recorded_agents" ]]; then
    echo "missing: dotagents source rules ($agents_target/rules/git.md); restore the source checkout before reinstalling" >&2
    link_issue=1
  fi
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
  fixed="$(fixed_install_entries global "$recorded_layout" "$installed_agents")"
  while IFS='|' read -r relative source kind label; do
    target="$target_root/$relative"
    [[ "$kind" != root ]] || continue # legacy root already diagnosed above
    if [[ "$recorded_layout" == managed ]] && ! managed_target_parent "$target_root" "$target"; then
      link_issue=1
      continue
    fi
    if [[ "$kind" == seed ]]; then
      # User-owned settings are deliberately not link targets or ledger rows.
      # Inspect only the required command and matcher; do not print config data.
      matcher=Bash
      [[ "$relative" != .codex/* ]] || matcher='^Bash$'
      if [[ -f "$target" && ! -L "$target" ]] && jq -e --arg matcher "$matcher" --arg command '"$HOME"/.agents/hooks/commit-message/pre-tool-use.sh' '
        any(.hooks.PreToolUse[]?; .matcher == $matcher and any(.hooks[]?; .type == "command" and .command == $command))
      ' "$target" >/dev/null 2>&1; then
        echo "ok: $label registration (user-owned $target)"
      else
        echo "missing: $label registration ($target); manually integrate the PreToolUse hook from $source into a regular user-owned file, then rerun doctor" >&2
        link_issue=1
      fi
    elif [[ "$kind" == host ]]; then
      adapter="$installed_agents/adapters/${relative#.}"
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
    else
      check_link "$target" "$source" "$label"
    fi
  done <<< "$fixed"
  # Diagnose the installed checkout's desired set, including declarations not
  # yet present in its install ledger. Do not use the calling worktree's set.
  if owned_skills="$(owned_skill_names "$installed_agents")"; then
    while IFS= read -r skill; do
      if [[ "$recorded_layout" != managed ]] || managed_target_parent "$target_root" "$target_root/.claude/skills/$skill"; then
        check_link "$target_root/.claude/skills/$skill" "$installed_agents/skills/owned/$skill" "Claude skill link ($skill)"
      else
        link_issue=1
      fi
      if [[ "$recorded_layout" == managed ]]; then
        if managed_target_parent "$target_root" "$target_root/.agents/skills/$skill"; then
          check_link "$target_root/.agents/skills/$skill" "$installed_agents/skills/owned/$skill" "shared skill link ($skill)"
        else
          link_issue=1
        fi
      fi
      # The alias is a tracked link inside the source checkout; the installer
      # does not create it, so a reinstall cannot bring it back.
      check_link "$installed_agents/skills/$skill" "$installed_agents/skills/owned/$skill" "shared skill alias ($skill)" "restore the alias in the source checkout"
    done <<< "$owned_skills"
  else
    echo "invalid: installed owned skill source; restore the source checkout before reinstalling" >&2
    link_issue=1
  fi
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
