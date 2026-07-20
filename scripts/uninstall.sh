#!/usr/bin/env bash
set -euo pipefail

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

echo "Mode: $MODE"
echo "Manifest: $manifest"
if [[ ! -f "$manifest" ]]; then
  echo "Nothing to remove: install manifest not found."
  exit 0
fi

echo "Recorded targets:"
while IFS=$'\t' read -r target source backup; do
  [[ -n "$target" ]] || continue
  echo "  $target"
done < "$manifest"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run: no changes made."
  exit 0
fi

remaining="${manifest}.remaining.$$"
: > "$remaining"
while IFS=$'\t' read -r target source backup; do
  [[ -n "$target" ]] || continue
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    unlink "$target"
    if [[ "$backup" != "-" && -e "$backup" && ! -e "$target" && ! -L "$target" ]]; then
      mv "$backup" "$target"
      echo "Restored backup: $target"
    fi
  else
    echo "Skipped modified or missing target: $target" >&2
    printf '%s\t%s\t%s\n' "$target" "$source" "$backup" >> "$remaining"
  fi
done < "$manifest"

if [[ -s "$remaining" ]]; then
  mv "$remaining" "$manifest"
  echo "Some entries were preserved; see $manifest" >&2
else
  unlink "$remaining"
  unlink "$manifest"
  manifest_dir="$(dirname "$manifest")"
  if [[ "$MODE" == "global" && "$manifest_dir" == */dotagents ]]; then
    rmdir "$manifest_dir" 2>/dev/null || true
  fi
fi
echo "Uninstall complete."
