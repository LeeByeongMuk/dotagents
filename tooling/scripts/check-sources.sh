#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
SKILLS_FILE="${DOTAGENTS_SKILLS_FILE:-$REPO_ROOT/agents/registry/skills.toml}"
SOURCES_FILE="${DOTAGENTS_SOURCES_FILE:-$REPO_ROOT/agents/registry/sources.lock}"
GH_BIN="${GH_BIN:-gh}"
SOURCE_TSV="$(mktemp "${TMPDIR:-/tmp}/dotagents-sources.XXXXXX")"
SKILL_TSV="$(mktemp "${TMPDIR:-/tmp}/dotagents-source-skills.XXXXXX")"

cleanup() {
  [[ -f "$SOURCE_TSV" ]] && unlink "$SOURCE_TSV" 2>/dev/null || true
  [[ -f "$SKILL_TSV" ]] && unlink "$SKILL_TSV" 2>/dev/null || true
}
trap cleanup EXIT

fail() {
  echo "error: $*" >&2
  exit 1
}

[[ -f "$SKILLS_FILE" && ! -L "$SKILLS_FILE" ]] || fail "skills registry is missing or unsafe"
[[ -f "$SOURCES_FILE" && ! -L "$SOURCES_FILE" ]] || fail "source lock is missing or unsafe"
command -v "$GH_BIN" >/dev/null 2>&1 || fail "GitHub CLI is required for source verification"

awk '
  function emit() {
    if (in_source) {
      if (id == "" || url == "" || revision == "") exit 2
      print id "\t" url "\t" revision
    }
  }
  $0 == "[[sources]]" { emit(); in_source=1; id=""; url=""; revision=""; next }
  in_source && /^id = "/ { value=$0; sub(/^id = "/, "", value); sub(/"$/, "", value); id=value; next }
  in_source && /^url = "/ { value=$0; sub(/^url = "/, "", value); sub(/"$/, "", value); url=value; next }
  in_source && /^revision = "/ { value=$0; sub(/^revision = "/, "", value); sub(/"$/, "", value); revision=value; next }
  END { emit() }
' "$SOURCES_FILE" > "$SOURCE_TSV" || fail "could not parse source lock"

awk '
  function emit() {
    if (in_skill && source_id != "") {
      if (path == "") exit 2
      print source_id "\t" path
    }
  }
  $0 == "[[skills]]" { emit(); in_skill=1; source_id=""; path=""; next }
  in_skill && /^source_id = "/ { value=$0; sub(/^source_id = "/, "", value); sub(/"$/, "", value); source_id=value; next }
  in_skill && /^path = "/ { value=$0; sub(/^path = "/, "", value); sub(/"$/, "", value); path=value; next }
  END { emit() }
' "$SKILLS_FILE" > "$SKILL_TSV" || fail "could not parse external skill entries"

failures=0
checks=0
while IFS=$'\t' read -r source_id path; do
  [[ -n "$source_id" && -n "$path" ]] || continue
  source_line="$(awk -F '\t' -v wanted="$source_id" '$1 == wanted { print; found=1; exit } END { if (!found) exit 1 }' "$SOURCE_TSV")" || {
    echo "error: external skill references unlocked source: $source_id" >&2
    failures=$((failures + 1))
    continue
  }
  IFS=$'\t' read -r _ source_url revision <<< "$source_line"
  case "$source_url" in
    https://github.com/*) repository="${source_url#https://github.com/}" ;;
    *)
      echo "error: unsupported source URL for $source_id" >&2
      failures=$((failures + 1))
      continue
      ;;
  esac
  repository="${repository%.git}"
  if [[ ! "$revision" =~ ^[0-9a-f]{40}$ || "$path" == /* || "$path" == *".."* ]]; then
    echo "error: unsafe pinned source entry: $source_id:$path" >&2
    failures=$((failures + 1))
    continue
  fi
  checks=$((checks + 1))
  if "$GH_BIN" api "repos/$repository/contents/$path?ref=$revision" --silent >/dev/null; then
    echo "ok: $source_id:$path"
  else
    echo "error: could not verify pinned source path: $source_id:$path" >&2
    failures=$((failures + 1))
  fi
done < "$SKILL_TSV"

[[ "$checks" -gt 0 ]] || fail "no external skill paths found"
[[ "$failures" -eq 0 ]] || exit 1
echo "All pinned source paths exist."
