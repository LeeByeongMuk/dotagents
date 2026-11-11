#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
DRY_RUN=0
FORCE=0
MODE="global"
PROJECT_DIR=""

usage() {
  echo "Usage: $0 [--dry-run] [--force] [--global | --project PATH]"
}

fail() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    --global) MODE="global" ;;
    --project)
      [[ $# -ge 2 ]] || fail "--project requires a path"
      MODE="project"
      PROJECT_DIR="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
  shift
done

timestamp="$(date +%Y%m%d%H%M%S)"
if [[ "$MODE" == "global" ]]; then
  target_root="${DOTAGENTS_HOME:-$HOME}"
  state_root="${XDG_STATE_HOME:-$target_root/.local/state}"
  manifest="$state_root/dotagents/install.tsv"
  entries=(
    "$target_root/.agents|$REPO_ROOT/agents"
    "$target_root/.claude/CLAUDE.md|$REPO_ROOT/dist/claude/CLAUDE.md"
    "$target_root/.claude/settings.json|$REPO_ROOT/agents/adapters/claude/settings.json"
    "$target_root/.claude/skills/product-development-workflow|$REPO_ROOT/agents/skills/owned/product-development-workflow"
    "$target_root/.claude/skills/fsd-refactor|$REPO_ROOT/agents/skills/owned/fsd-refactor"
    "$target_root/.claude/skills/dotagents-promote|$REPO_ROOT/agents/skills/owned/dotagents-promote"
    "$target_root/.claude/skills/usage-guide|$REPO_ROOT/agents/skills/owned/usage-guide"
    "$target_root/.codex/AGENTS.md|$REPO_ROOT/dist/codex/AGENTS.md"
    "$target_root/.codex/hooks.json|$REPO_ROOT/agents/adapters/codex/hooks.json"
    "$target_root/.gemini/GEMINI.md|$REPO_ROOT/dist/gemini/GEMINI.md"
  )
else
  [[ -n "$PROJECT_DIR" ]] || fail "project path is required"
  [[ -d "$PROJECT_DIR" ]] || fail "project directory does not exist: $PROJECT_DIR"
  target_root="$(cd "$PROJECT_DIR" && pwd -P)"
  [[ "$target_root" != "$REPO_ROOT" ]] || fail "refusing to install project links into the dotagents repository itself"
  manifest="$target_root/.dotagents-install.tsv"
  entries=(
    "$target_root/.agents|$REPO_ROOT/agents"
    "$target_root/AGENTS.md|$REPO_ROOT/dist/codex/AGENTS.md"
    "$target_root/CLAUDE.md|$REPO_ROOT/dist/claude/CLAUDE.md"
    "$target_root/.claude/skills/product-development-workflow|$REPO_ROOT/agents/skills/owned/product-development-workflow"
    "$target_root/.claude/skills/fsd-refactor|$REPO_ROOT/agents/skills/owned/fsd-refactor"
    "$target_root/.claude/skills/dotagents-promote|$REPO_ROOT/agents/skills/owned/dotagents-promote"
    "$target_root/.claude/skills/usage-guide|$REPO_ROOT/agents/skills/owned/usage-guide"
    "$target_root/GEMINI.md|$REPO_ROOT/dist/gemini/GEMINI.md"
  )
fi

# A global install into the real home makes this checkout the live
# configuration for every session, so it runs only from the primary checkout
# on main. A dry run reports the problem instead of stopping.
if [[ "$MODE" == "global" && "$target_root" == "$HOME" ]] && git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  live_problem=""
  git_dir="$(cd "$REPO_ROOT" && cd "$(git rev-parse --git-dir)" && pwd -P)"
  common_dir="$(cd "$REPO_ROOT" && cd "$(git rev-parse --git-common-dir)" && pwd -P)"
  branch="$(git -C "$REPO_ROOT" symbolic-ref --quiet --short HEAD || true)"
  if [[ "$git_dir" != "$common_dir" ]]; then
    live_problem="this is a linked worktree; install from the primary checkout"
  elif [[ "$branch" != "main" ]]; then
    live_problem="the checkout is on ${branch:-a detached HEAD}; switch it to main"
  fi
  if [[ -n "$live_problem" ]]; then
    [[ "$DRY_RUN" -eq 1 ]] || fail "refusing a global install: $live_problem"
    echo "Warning: a real run would refuse: $live_problem"
  fi
fi

validate_target_parent() {
  local target="$1"
  local parent relative current component
  local -a components
  [[ "$target" == "$target_root"/* ]] || fail "install target escapes the target root: $target"
  parent="$(dirname "$target")"
  [[ "$parent" == "$target_root" ]] && return 0
  relative="${parent#"$target_root"/}"
  current="$target_root"
  IFS='/' read -r -a components <<< "$relative"
  for component in "${components[@]}"; do
    [[ -n "$component" && "$component" != "." && "$component" != ".." ]] || fail "unsafe install path component: $target"
    current="$current/$component"
    if [[ "$MODE" == "project" && -L "$current" ]]; then
      fail "project install parent must not be a symbolic link: $current"
    fi
    if [[ -e "$current" || -L "$current" ]]; then
      [[ -d "$current" ]] || fail "install parent is not a directory: $current"
    fi
  done
}

for entry in "${entries[@]}"; do
  validate_target_parent "${entry%%|*}"
done

echo "Mode: $MODE"
echo "Repository: $REPO_ROOT"
echo "Manifest: $manifest"
echo "Targets:"
for entry in "${entries[@]}"; do
  echo "  ${entry%%|*} -> ${entry#*|}"
done

previous_source() {
  local wanted="$1"
  [[ -f "$manifest" ]] || return 1
  awk -F '\t' -v target="$wanted" '$1 == target { print $2; found=1; exit } END { if (!found) exit 1 }' "$manifest"
}

previous_backup() {
  local wanted="$1"
  [[ -f "$manifest" ]] || return 1
  awk -F '\t' -v target="$wanted" '$1 == target { print $3; found=1; exit } END { if (!found) exit 1 }' "$manifest"
}

is_current_target() {
  local wanted="$1" entry
  for entry in "${entries[@]}"; do
    [[ "${entry%%|*}" == "$wanted" ]] && return 0
  done
  return 1
}

# Targets an earlier install recorded that this version no longer declares.
retired=()
if [[ -f "$manifest" ]]; then
  while IFS=$'\t' read -r target _ _; do
    [[ -n "$target" ]] || continue
    is_current_target "$target" || retired+=("$target")
  done < "$manifest"
fi
if [[ ${#retired[@]} -gt 0 ]]; then
  echo "Retired targets to remove:"
  printf '  %s\n' "${retired[@]}"
fi

conflicts=()
for entry in "${entries[@]}"; do
  target="${entry%%|*}"
  source="${entry#*|}"
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    continue
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    if [[ -L "$target" ]]; then
      current="$(readlink "$target")"
      recorded="$(previous_source "$target" 2>/dev/null || true)"
      if [[ -n "$recorded" && "$current" == "$recorded" ]]; then
        continue
      fi
      case "$current" in
        "$REPO_ROOT"/*) continue ;;
      esac
    fi
    conflicts+=("$target")
  fi
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  if [[ ${#conflicts[@]} -gt 0 ]]; then
    echo "Dry run: ${#conflicts[@]} conflict(s) found; a real run would stop unless --force is used."
  fi
  echo "Dry run: no changes made."
  exit 0
fi

if [[ ${#conflicts[@]} -gt 0 && "$FORCE" -ne 1 ]]; then
  echo "Conflicts detected; nothing was changed:" >&2
  printf '  %s\n' "${conflicts[@]}" >&2
  echo "Review them or rerun with --force to back them up first." >&2
  exit 2
fi

mkdir -p "$(dirname "$manifest")"
transaction_dir="$(mktemp -d "${manifest}.transaction.XXXXXX")"
temp_manifest="$transaction_dir/install.tsv"
committed=0
manifest_commit_started=0
undo_kind=()
undo_from=()
undo_to=()

finish_install() {
  local status=$? index kind original destination rollback_failed=0
  trap - EXIT INT TERM
  set +e
  if [[ "$committed" -ne 1 ]]; then
    echo "Installation failed; rolling back changes." >&2
    for ((index=${#undo_kind[@]}-1; index>=0; index--)); do
      kind="${undo_kind[$index]}"
      original="${undo_from[$index]}"
      destination="${undo_to[$index]}"
      if [[ "$kind" == "link" ]]; then
        if [[ -L "$destination" && "$(readlink "$destination")" == "$original" ]]; then
          unlink "$destination" || rollback_failed=1
        elif [[ -e "$destination" || -L "$destination" ]]; then
          echo "Cannot roll back changed target: $destination" >&2
          rollback_failed=1
        fi
      elif [[ -e "$destination" || -L "$destination" ]]; then
        if [[ -e "$original" || -L "$original" ]]; then
          echo "Cannot restore occupied target: $original" >&2
          rollback_failed=1
        else
          mv "$destination" "$original" || rollback_failed=1
        fi
      fi
    done
    if [[ "$manifest_commit_started" -eq 1 ]]; then
      if [[ -e "$transaction_dir/previous-manifest" || -L "$transaction_dir/previous-manifest" ]]; then
        mv "$transaction_dir/previous-manifest" "$manifest" || rollback_failed=1
      else
        rm -f "$manifest" || rollback_failed=1
      fi
    fi
  fi
  if [[ "$rollback_failed" -eq 0 ]]; then
    rm -r "$transaction_dir"
  else
    echo "Rollback incomplete; recovery files kept in: $transaction_dir" >&2
  fi
  exit "$status"
}

trap finish_install EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if [[ -e "$manifest" || -L "$manifest" ]]; then
  cp -Pp "$manifest" "$transaction_dir/previous-manifest"
fi
: > "$temp_manifest"

# Record undo operations before each mutation so errors and signals can also
# recover the target whose replacement has not finished yet.
move_for_install() {
  undo_kind+=("move") undo_from+=("$1") undo_to+=("$2")
  mv "$1" "$2"
}

backup_target() {
  local target="$1" suffix=0
  backup="${target}.dotagents-backup.${timestamp}"
  while [[ -e "$backup" || -L "$backup" ]]; do
    suffix=$((suffix + 1))
    backup="${target}.dotagents-backup.${timestamp}.${suffix}"
  done
  move_for_install "$target" "$backup"
}

for entry in "${entries[@]}"; do
  target="${entry%%|*}"
  source="${entry#*|}"
  validate_target_parent "$target"
  backup="$(previous_backup "$target" 2>/dev/null || echo '-')"

  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    printf '%s\t%s\t%s\n' "$target" "$source" "$backup" >> "$temp_manifest"
    continue
  fi

  if [[ -L "$target" ]]; then
    current="$(readlink "$target")"
    recorded="$(previous_source "$target" 2>/dev/null || true)"
    case "$current" in
      "$recorded") move_for_install "$target" "$transaction_dir/link.${#undo_kind[@]}" ;;
      "$REPO_ROOT"/*) move_for_install "$target" "$transaction_dir/link.${#undo_kind[@]}" ;;
      *) backup_target "$target" ;;
    esac
  elif [[ -e "$target" ]]; then
    backup_target "$target"
  fi

  mkdir -p "$(dirname "$target")"
  undo_kind+=("link") undo_from+=("$source") undo_to+=("$target")
  ln -s "$source" "$target"
  printf '%s\t%s\t%s\n' "$target" "$source" "$backup" >> "$temp_manifest"
done

# Remove retired links and restore the backups they replaced, as uninstall
# would. A target changed since install is left alone.
if [[ ${#retired[@]} -gt 0 ]]; then
  for target in "${retired[@]}"; do
    source="$(previous_source "$target" 2>/dev/null || true)"
    backup="$(previous_backup "$target" 2>/dev/null || echo '-')"
    if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
      move_for_install "$target" "$transaction_dir/link.${#undo_kind[@]}"
      echo "Removed retired link: $target"
      if [[ "$backup" != "-" && ( -e "$backup" || -L "$backup" ) && ! -e "$target" && ! -L "$target" ]]; then
        move_for_install "$backup" "$target"
        echo "Restored backup: $target"
      fi
    else
      echo "Left retired target that changed after install: $target" >&2
    fi
  done
fi

manifest_commit_started=1
mv "$temp_manifest" "$manifest"
committed=1
echo "Installation complete."
