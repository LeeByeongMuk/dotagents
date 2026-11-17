#!/usr/bin/env bash
# Project-owned starters and read-only readiness evidence; no global installation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"

usage() {
  cat <<'EOF'
Usage:
  project.sh inspect PROJECT
  project.sh doctor PROJECT
  project.sh init PROJECT [--template generic|nextjs] [--dry-run|--apply]

PROJECT must be an existing directory. init previews by default; --apply adds
missing local starter files. Existing files and symlinks are always preserved.
inspect and doctor never run project commands. doctor exits 1 for missing evidence.
EOF
}
fail() { echo "error: $*" >&2; exit 1; }
[[ $# -gt 0 ]] || { usage >&2; exit 2; }
case "$1" in -h|--help) usage; exit 0 ;; esac
action="$1"; shift
case "$action" in inspect|doctor|init) ;; *) usage >&2; exit 2 ;; esac
[[ $# -gt 0 && "$1" != -* ]] || fail "select an existing project directory"
selected="$1"; shift
template=generic
apply=0
mode_seen=0
while [[ $# -gt 0 ]]; do
  [[ "$action" == init ]] || fail "options are only supported by init"
  case "$1" in
    --template) [[ $# -ge 2 ]] || fail "--template requires a name"; template="$2"; shift 2 ;;
    --apply|--dry-run)
      [[ "$mode_seen" -eq 0 ]] || fail "choose either --apply or --dry-run"
      mode_seen=1
      [[ "$1" != --apply ]] || apply=1
      shift ;;
    *) fail "unknown option: $1" ;;
  esac
done
case "$template" in generic|nextjs) ;; *) fail "unsupported template: $template" ;; esac
[[ "$selected" != *$'\n'* && "$selected" != *$'\t'* ]] || fail "project path contains a line separator"
[[ -d "$selected" ]] || fail "project directory does not exist"
project="$(cd "$selected" && pwd -P)"

# Reject symlink components for mutation, including a selected directory alias.
# Read-only commands may inspect an alias but never traverse instruction links.
check_components() {
  local cursor="$1"
  while [[ "$cursor" != / && "$cursor" == */ ]]; do cursor="${cursor%/}"; done
  while [[ "$cursor" != / && "$cursor" != . ]]; do
    [[ ! -L "$cursor" ]] || fail "refusing a symlink path component: $cursor"
    cursor="$(dirname "$cursor")"
  done
}

if [[ "$action" != init ]]; then
  missing=0
  instructions=0
  verification=0
  echo "project: $project"
  for relative in AGENTS.md CLAUDE.md GEMINI.md .agents; do
    target="$project/$relative"
    if [[ -L "$target" ]]; then
      echo "link: $relative (preserved; target not inspected)"
    elif [[ -f "$target" ]]; then
      echo "local: $relative"
      [[ "$relative" == .agents ]] || instructions=1
      if [[ "$relative" != .agents ]] && LC_ALL=C grep -Eiq '^#{1,6} +(verification|validation|검증)' "$target"; then
        verification=1
      fi
    elif [[ -d "$target" ]]; then
      echo "local directory: $relative (contents not traversed)"
    elif [[ -e "$target" ]]; then
      echo "unsupported: $relative (not inspected)"
    else
      echo "missing: $relative"
    fi
  done
  if [[ "$instructions" -eq 0 ]]; then
    echo 'gap: no regular project-local instruction file'
    missing=1
  fi
  context=0
  for relative in .ai-context docs/context docs/architecture; do
    # Do not follow a symlink at any component of the inspected relative path.
    if [[ -L "$project/${relative%%/*}" || -L "$project/$relative" ]]; then
      echo "link: $relative (target not inspected)"
    elif [[ -d "$project/$relative" ]]; then
      echo "context location: $relative (content and completeness not validated)"
      context=1
    fi
  done
  if [[ "$context" -eq 0 ]]; then
    echo 'gap: no context directory at .ai-context, docs/context, or docs/architecture; inspect project-specific references manually'
    missing=1
  fi
  for relative in package-lock.json npm-shrinkwrap.json pnpm-lock.yaml yarn.lock bun.lock bun.lockb; do
    if [[ -L "$project/$relative" ]]; then
      echo "link: $relative (target not inspected)"
    elif [[ -f "$project/$relative" ]]; then
      echo "package manager evidence: $relative"
    fi
  done
  if [[ -L "$project/package.json" ]]; then
    echo 'link: package.json (target not inspected)'
  elif [[ -f "$project/package.json" ]]; then
    command -v jq >/dev/null 2>&1 || fail "jq is required to inspect package.json"
    # Report only known script names, never command contents or arbitrary metadata.
    if scripts="$(jq -er 'if type != "object" then error("object required") elif has("scripts") then .scripts else {} end | if type != "object" then error("scripts object required") else keys[] | select(test("^(build|check|lint|test|typecheck)(:[A-Za-z0-9_-]+)*$")) end' "$project/package.json" 2>/dev/null)"; then
      while IFS= read -r name; do echo "verification candidate: package.json script $name (not executed)"; done <<< "$scripts"
      verification=1
    elif jq -e 'type == "object" and (if has("scripts") then (.scripts | type == "object") else true end)' "$project/package.json" >/dev/null 2>&1; then
      echo 'gap: no recognized verification script names in package.json'
    else
      echo 'gap: package.json is invalid or scripts is not an object'
      missing=1
    fi
  fi
  if [[ "$verification" -eq 0 ]]; then
    echo 'gap: no verification heading or recognized package script; record actual project checks'
    missing=1
  else
    echo 'verification: guidance or script names found; no commands executed and no passing checks established'
  fi
  echo 'scope: root instruction files and common context locations only; nested instructions and custom conventions require manual review'
  [[ "$action" != doctor || "$missing" -eq 0 ]]
  exit $?
fi

case "$selected" in /*) lexical="$selected" ;; *) lexical="$PWD/$selected" ;; esac
check_components "$lexical"
# Never turn the source checkout, home, filesystem root, or their ancestors into
# a target project. Descendants of the checkout are also source-owned.
case "$project/" in "$REPO_ROOT/"*) fail "project is inside the dotagents source checkout" ;; esac
for protected in / "$REPO_ROOT" "${HOME:-/}"; do
  case "$protected/" in "$project/"*) fail "project is a protected directory or its ancestor" ;; esac
done
case "$project/" in */.git/*|*/.agents/*|*/.claude/*|*/.codex/*|*/.gemini/*) fail "project is inside a tool configuration directory" ;; esac

sources=("$REPO_ROOT/agents/templates/$template/AGENTS.md" "$REPO_ROOT/agents/templates/context-docs/project-readme.md")
destinations=(AGENTS.md .ai-context/README.md)
planned=()
for index in 0 1; do
  [[ -f "${sources[$index]}" && ! -L "${sources[$index]}" ]] || fail "starter source is missing or linked"
  relative="${destinations[$index]}"
  target="$project/$relative"
  if [[ "$relative" == */* ]]; then
    parent="$project/${relative%/*}"
    [[ ! -L "$parent" ]] || fail "refusing linked context directory: ${relative%/*}"
    [[ ! -e "$parent" || -d "$parent" ]] || fail "context parent is not a directory: ${relative%/*}"
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    echo "preserve: $relative"
  else
    planned+=("$index")
    echo "create: $relative (source: ${sources[$index]#"$REPO_ROOT/"})"
  fi
done
[[ "$apply" -eq 1 ]] || { echo 'preview only: repeat with --apply to add these files'; exit 0; }
[[ "${#planned[@]}" -gt 0 ]] || { echo 'no changes: existing project files preserved'; exit 0; }

# Stage every byte before publishing. Add-only hard links refuse existing names;
# rollback removes only the exact staged inode, preserving concurrent replacements.
stage="$(mktemp -d "$project/.dotagents-project.XXXXXX")"
created=()
context_created=0
committed=0
cleanup() {
  local index target
  if [[ "$committed" -eq 0 ]]; then
    for index in "${created[@]}"; do
      target="$project/${destinations[$index]}"
      if [[ ! -L "$target" && "$target" -ef "$stage/${destinations[$index]##*/}" ]]; then rm -- "$target"; fi
    done
    if [[ "$context_created" -eq 1 ]]; then rmdir "$project/.ai-context" 2>/dev/null || true; fi
  fi
  rm -r -- "$stage"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
for index in "${planned[@]}"; do
  staged="$stage/${destinations[$index]##*/}"
  cat "${sources[$index]}" > "$staged"
  if [[ "$index" -eq 0 ]]; then
    printf '\n## Starter source\n\n- dotagents `%s`; maintained template, not observed project conventions.\n- Read `.ai-context/README.md` and record verified project facts and checks in this file’s Verification section before relying on this starter.\n' "${sources[$index]#"$REPO_ROOT/"}" >> "$staged"
  fi
done
for index in "${planned[@]}"; do
  check_components "$lexical"
  if [[ "${destinations[$index]}" == */* ]]; then
    [[ ! -L "$project/.ai-context" ]] || fail "context directory became a symlink"
    if [[ ! -e "$project/.ai-context" ]]; then
      mkdir "$project/.ai-context"
      context_created=1
    fi
    [[ -d "$project/.ai-context" ]] || fail "context parent is not a directory"
  fi
  # Passing the parent directory fixes the link name to the staged basename;
  # an existing directory or symlink at that name must not be traversed.
  created+=("$index")
  ln "$stage/${destinations[$index]##*/}" "$project/$(dirname "${destinations[$index]}")/"
done
committed=1
echo 'applied: local starters added; review placeholders and run actual project checks'
