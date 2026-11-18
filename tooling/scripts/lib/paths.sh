#!/usr/bin/env bash

# Resolve existing symlinks without requiring every path component to exist.
# An optional forbidden entry prevents following a link that may change during
# an install or removal. Its current destination is not enough to check this.
resolve_path() {
  local pending="$1" forbidden="${2:-}" resolved=/ component candidate link links=0
  [[ "$pending" == /* ]] || pending="$PWD/$pending"
  while [[ -n "$pending" ]]; do
    component="${pending%%/*}"
    if [[ "$pending" == */* ]]; then pending="${pending#*/}"; else pending=''; fi
    case "$component" in
      ''|.) continue ;;
      ..) resolved="${resolved%/*}"; resolved="${resolved:-/}"; continue ;;
    esac
    candidate="${resolved%/}/$component"
    if [[ -n "$forbidden" && ( "$candidate" == "$forbidden" || "$candidate" -ef "$forbidden" ) ]]; then
      return 1
    fi
    if [[ -L "$candidate" ]]; then
      links=$((links + 1))
      [[ "$links" -le 40 ]] || return 1
      link="$(readlink "$candidate")" || return 1
      [[ "$link" != /* ]] || resolved=/
      pending="$link${pending:+/$pending}"
    else
      resolved="$candidate"
    fi
  done
  printf '%s\n' "$resolved"
}

# Compare ancestors by filesystem identity as well as spelling. This handles
# existing paths reached through alternate case or a directory alias.
path_is_within() {
  local directory="$1" path="$2"
  while :; do
    [[ "$path" != "$directory" && ! "$path" -ef "$directory" ]] || return 0
    [[ "$path" != / ]] || return 1
    path="${path%/*}"
    path="${path:-/}"
  done
}
