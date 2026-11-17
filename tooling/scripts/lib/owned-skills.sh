#!/usr/bin/env bash
# Shared desired set; callers must check the exit status before using output.
# Validate the entire set before emitting names, so partial source damage cannot
# silently retire installed links. Keep this compatible with Bash 3.2.
owned_skill_names() (
  local agents_root="$1" path name
  local LC_ALL=C
  local -a names=()
  [[ -d "$agents_root/skills/owned" ]] || {
    echo "error: missing owned skill directory: $agents_root/skills/owned" >&2
    return 1
  }
  shopt -s nullglob dotglob
  for path in "$agents_root"/skills/owned/*; do
    # owned/README.md and other documentation files are not skills.
    [[ -d "$path" || -L "$path" ]] || continue
    name="${path##*/}"
    [[ "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]] || {
      echo "error: invalid owned skill name: $name" >&2
      return 1
    }
    [[ -d "$path" && ! -L "$path" && -f "$path/SKILL.md" ]] || {
      echo "error: incomplete owned skill directory: $path (expected a real directory with SKILL.md)" >&2
      return 1
    }
    names+=("$name")
  done
  [[ ${#names[@]} -gt 0 ]] || {
    echo "error: owned skill set is empty: $agents_root/skills/owned" >&2
    return 1
  }
  printf '%s\n' "${names[@]}" | LC_ALL=C sort
)
