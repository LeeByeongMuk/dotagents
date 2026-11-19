#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
source "$SCRIPT_DIR/lib/install-layout.sh"
source "$SCRIPT_DIR/lib/paths.sh"

DRY_RUN=0
MODE="global"
PROJECT_DIR=""

usage() {
  echo "Usage: $0 [--dry-run] [--global | --project PATH]"
}

fail() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
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

if [[ "$MODE" == "global" ]]; then
  target_root="${DOTAGENTS_HOME:-$HOME}"
  state_root="${XDG_STATE_HOME:-$target_root/.local/state}"
  manifest="$state_root/dotagents/install.tsv"
else
  [[ -n "$PROJECT_DIR" ]] || fail "project path is required"
  [[ -d "$PROJECT_DIR" ]] || fail "project directory does not exist: $PROJECT_DIR"
  target_root="$(cd "$PROJECT_DIR" && pwd -P)"
  manifest="$target_root/.dotagents-install.tsv"
fi

metadata="${manifest}.meta.tsv"
read_install_layout "$manifest" "$target_root" || fail "invalid installation metadata; restore it before removal"
if [[ -f "$manifest" ]]; then
  previous_legacy_repo=""
  if [[ "$recorded_layout" == legacy ]]; then
    previous_legacy_repo="$(legacy_recorded_repository "$manifest" "$target_root")"
  fi
  while IFS=$'\t' read -r target _ _; do
    [[ -n "$target" && "$target" != "$MANAGED_LEDGER_HEADER" ]] || continue
    if [[ "$recorded_layout" == managed ]]; then
      managed_target_parent "$target_root" "$target" || fail "unsafe managed removal target: $target"
    else
      legacy_target_parent "$target_root" "$target" "$REPO_ROOT" "$previous_legacy_repo" || fail "unsafe legacy removal target: $target; check for a parent through .agents or a source checkout"
    fi
  done < "$manifest"
fi

echo "Mode: $MODE"
echo "Manifest: $manifest"
if [[ ! -f "$manifest" ]]; then
  echo "Nothing to remove: install manifest not found."
  exit 0
fi

echo "Recorded targets:"
while IFS=$'\t' read -r target source backup; do
  [[ -n "$target" && "$target" != "$MANAGED_LEDGER_HEADER" ]] || continue
  echo "  $target"
done < "$manifest"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run: no changes made."
  exit 0
fi

remaining="${manifest}.remaining.$$"
: > "$remaining"
if [[ "$recorded_layout" == managed ]]; then
  printf '%s\n' "$MANAGED_LEDGER_HEADER" > "$remaining"
fi
while IFS=$'\t' read -r target source backup; do
  [[ -n "$target" && "$target" != "$MANAGED_LEDGER_HEADER" ]] || continue
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    unlink "$target"
    if [[ "$backup" != "-" && ( -e "$backup" || -L "$backup" ) && ! -e "$target" && ! -L "$target" ]]; then
      mv "$backup" "$target"
      echo "Restored backup: $target"
    fi
  else
    echo "Skipped modified or missing target: $target" >&2
    printf '%s\t%s\t%s\n' "$target" "$source" "$backup" >> "$remaining"
  fi
done < "$manifest"

if [[ -s "$remaining" ]] && { [[ "$recorded_layout" != managed ]] || grep -Fvxq -- "$MANAGED_LEDGER_HEADER" "$remaining"; }; then
  mv "$remaining" "$manifest"
  echo "Some entries were preserved; see $manifest" >&2
else
  unlink "$remaining"
  unlink "$manifest"
  if [[ "$recorded_layout" == managed ]]; then
    unlink "$metadata"
    echo "User-owned settings seeds and shared directories were preserved; remove the hook registration manually if no longer needed."
  fi
  manifest_dir="$(dirname "$manifest")"
  if [[ "$MODE" == "global" && "$manifest_dir" == */dotagents ]]; then
    rmdir "$manifest_dir" 2>/dev/null || true
  fi
fi
echo "Uninstall complete."
