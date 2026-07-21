#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
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
    "$target_root/.claude/CLAUDE.md|$REPO_ROOT/claude/CLAUDE.md"
    "$target_root/.codex/AGENTS.md|$REPO_ROOT/codex/AGENTS.md"
    "$target_root/.gemini/GEMINI.md|$REPO_ROOT/gemini/GEMINI.md"
  )
else
  [[ -n "$PROJECT_DIR" ]] || fail "project path is required"
  [[ -d "$PROJECT_DIR" ]] || fail "project directory does not exist: $PROJECT_DIR"
  target_root="$(cd "$PROJECT_DIR" && pwd -P)"
  [[ "$target_root" != "$REPO_ROOT" ]] || fail "refusing to install project links into the dotagents repository itself"
  manifest="$target_root/.dotagents-install.tsv"
  entries=(
    "$target_root/.agents|$REPO_ROOT/agents"
    "$target_root/AGENTS.md|$REPO_ROOT/codex/AGENTS.md"
    "$target_root/CLAUDE.md|$REPO_ROOT/claude/CLAUDE.md"
    "$target_root/GEMINI.md|$REPO_ROOT/gemini/GEMINI.md"
  )
fi

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
temp_manifest="${manifest}.tmp.$$"
: > "$temp_manifest"

for entry in "${entries[@]}"; do
  target="${entry%%|*}"
  source="${entry#*|}"
  backup="$(previous_backup "$target" 2>/dev/null || echo '-')"

  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    printf '%s\t%s\t%s\n' "$target" "$source" "$backup" >> "$temp_manifest"
    continue
  fi

  if [[ -L "$target" ]]; then
    current="$(readlink "$target")"
    recorded="$(previous_source "$target" 2>/dev/null || true)"
    case "$current" in
      "$recorded") unlink "$target" ;;
      "$REPO_ROOT"/*) unlink "$target" ;;
      *)
        backup="${target}.dotagents-backup.${timestamp}"
        mv "$target" "$backup"
        ;;
    esac
  elif [[ -e "$target" ]]; then
    backup="${target}.dotagents-backup.${timestamp}"
    mv "$target" "$backup"
  fi

  mkdir -p "$(dirname "$target")"
  ln -s "$source" "$target"
  printf '%s\t%s\t%s\n' "$target" "$source" "$backup" >> "$temp_manifest"
done

mv "$temp_manifest" "$manifest"
echo "Installation complete."
