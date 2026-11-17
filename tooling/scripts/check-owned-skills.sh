#!/usr/bin/env bash
# Build-time consistency checks, not an install-time metadata parser.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/lib/owned-skills.sh"
agents_root="${1:-$SCRIPT_DIR/../../agents}"
fail() { echo "error: $*" >&2; exit 1; }
names="$(owned_skill_names "$agents_root")" || exit 1
owned_root="$(cd "$agents_root/skills/owned" && pwd -P)"
shopt -s nullglob dotglob

while IFS= read -r name; do
  alias="$agents_root/skills/$name"
  [[ -L "$alias" && "$(readlink "$alias")" == "owned/$name" && -f "$alias/SKILL.md" ]] || fail "owned skill discovery alias must link owned/$name: $alias"
done <<< "$names"
# Reject stale or extra owned aliases as well as missing/wrong primary aliases.
for alias in "$agents_root"/skills/*; do
  [[ -L "$alias" ]] || continue
  destination="$(readlink "$alias")"
  resolved="$(cd "$alias" 2>/dev/null && pwd -P || true)"
  case "$destination|$resolved" in
    owned/*|*\|"$owned_root"/*)
      name="${alias##*/}"
      [[ "$destination" == "owned/$name" ]] && grep -Fqx -- "$name" <<< "$names" || fail "unexpected owned skill alias: $alias -> $destination"
      ;;
  esac
done

registry="$agents_root/registry/skills.toml"
[[ -f "$registry" ]] || fail "missing skill registry: $registry"
# Read only id/kind/source in the registry's documented flat [[skills]] schema.
# No TOML package or runtime install dependency is introduced. Reject ambiguous
# or malformed contract fields rather than guessing metadata for owned entries.
rows="$(awk '
  function error(message) { print "error: skill registry " message > "/dev/stderr"; invalid=1 }
  function finish() {
    if (!in_skill) return
    if (id == "" || kind == "") error("entry needs id and kind")
    if (seen[id]++) error("duplicate id: " id)
    if (kind == "owned") {
      if (source == "") error("owned entry needs source: " id)
      print id "\t" source
    }
  }
  /^\[\[skills\]\][[:space:]]*$/ { finish(); in_skill=1; id=""; kind=""; source=""; delete fields; next }
  in_skill && /^[[:space:]]*(id|kind|source)[[:space:]]*=/ {
    key=$0; sub(/^[[:space:]]*/, "", key); sub(/[[:space:]]*=.*/, "", key)
    if (fields[key]++) error("duplicate field: " key)
    value=$0; sub(/^[^=]*=[[:space:]]*/, "", value)
    if (value !~ /^"[^"\\]*"[[:space:]]*(#.*)?$/) { error("malformed field: " key); next }
    sub(/^"/, "", value); sub(/"[[:space:]]*(#.*)?$/, "", value)
    if (key == "id") id=value
    if (key == "kind") kind=value
    if (key == "source") source=value
  }
  END { finish(); if (invalid) exit 1 }
' "$registry")" || exit 1
expected="$(while IFS= read -r name; do printf '%s\tagents/skills/owned/%s\n' "$name" "$name"; done <<< "$names")"
[[ "$(printf '%s\n' "$rows" | LC_ALL=C sort)" == "$expected" ]] || fail "owned registry IDs and source paths must match owned skill directories"
echo 'Owned skill aliases and registry passed.'
