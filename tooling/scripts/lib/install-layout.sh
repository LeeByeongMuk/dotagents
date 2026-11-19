#!/usr/bin/env bash
MANAGED_LEDGER_HEADER='# dotagents-layout=managed-v1'

# Fixed installation declarations and the bounded global managed-layout contract.
# Format: target relative to home/project | source | kind | diagnostic label.
fixed_install_entries() {
  local mode="$1" layout="$2" agents="$3" repo
  repo="$(dirname "$agents")"
  if [[ "$mode" == project ]]; then
    printf '%s\n' ".agents|$agents|root|managed .agents link" \
      "AGENTS.md|$repo/dist/codex/AGENTS.md|host|host entry point" \
      "CLAUDE.md|$repo/dist/claude/CLAUDE.md|host|host entry point" \
      "GEMINI.md|$repo/dist/gemini/GEMINI.md|host|host entry point"
    return
  fi
  if [[ "$layout" == legacy ]]; then
    printf '%s\n' ".agents|$agents|root|managed .agents link"
  else
    printf '%s\n' ".agents/rules|$agents/rules|link|shared rules link" \
      ".agents/hooks|$agents/hooks|link|shared hooks link" \
      ".agents/templates|$agents/templates|link|shared templates link"
  fi
  printf '%s\n' ".claude/CLAUDE.md|$repo/dist/claude/CLAUDE.md|host|host entry point" \
    ".codex/AGENTS.md|$repo/dist/codex/AGENTS.md|host|host entry point" \
    ".gemini/GEMINI.md|$repo/dist/gemini/GEMINI.md|host|host entry point"
  if [[ "$layout" == legacy ]]; then
    printf '%s\n' ".claude/settings.json|$agents/adapters/claude/settings.json|link|Claude settings link" \
      ".codex/hooks.json|$agents/adapters/codex/hooks.json|link|Codex commit hook link"
  else
    printf '%s\n' ".claude/settings.json|$agents/adapters/claude/hooks.example.json|seed|Claude required commit hook" \
      ".codex/hooks.json|$agents/adapters/codex/hooks.json|seed|Codex required commit hook"
  fi
}

# Reject symlinked parents before managed writes, including retirement/removal.
# Existing shared directories remain user-owned; --force does not bypass this.
managed_target_parent() {
  local root="$1" target="$2" relative current component component_index
  local -a components
  [[ "$target" == "$root"/* && ! -L "$root" ]] || {
    echo "error: unsafe managed target root: $target" >&2; return 1;
  }
  relative="${target#"$root"/}"
  IFS='/' read -r -a components <<< "$relative"
  current="$root"
  for ((component_index=0; component_index<${#components[@]}-1; component_index++)); do
    component="${components[$component_index]}"
    [[ -n "$component" && "$component" != . && "$component" != .. ]] || return 1
    current="$current/$component"
    if [[ -L "$current" || ( -e "$current" && ! -d "$current" ) ]]; then
      echo "error: managed install parent must be a real directory: $current; review/uninstall the legacy layout before reinstalling" >&2
      return 1
    fi
  done
  component="${components[${#components[@]}-1]}"
  [[ -n "$component" && "$component" != . && "$component" != .. ]]
}

# The legacy root link can change during install or when its backup is restored.
# Reject any parent path that passes through it, or reaches a source checkout
# directly. Ordinary symlinked host directories outside those roots still work.
legacy_target_parent() {
  local root="$1" target="$2" repo="$3" previous_repo="$4" relative parent resolved_root
  [[ "$target" == "$root"/* ]] || return 1
  relative="${target#"$root"/}"
  case "/$relative/" in *'/../'*|*'/./'*|*'//'*) return 1 ;; esac
  resolved_root="$(resolve_path "$root")" || return 1
  parent="$(resolve_path "${target%/*}" "${resolved_root%/}/.agents")" || return 1
  ! path_is_within "$repo" "$parent" || return 1
  [[ -z "$previous_repo" ]] || ! path_is_within "$previous_repo" "$parent"
}

legacy_recorded_repository() {
  local manifest="$1" root="$2" agents
  [[ -f "$manifest" ]] || return 0
  agents="$(awk -F '\t' -v target="$root/.agents" '$1 == target { print $2; exit }' "$manifest")"
  if [[ "$agents" == /*/agents ]]; then
    printf '%s\n' "${agents%/agents}"
  fi
}

# Sidecar is data, never sourced. Old ledgers retain the unchanged three-column
# format. Only managed installs need explicit metadata; a legacy .agents row or
# an unrecorded legacy symlink remains supported by the calling diagnostic.
read_install_layout() {
  local manifest="$1" root="$2" metadata line key value count=0 keys='|'
  metadata="${manifest}.meta.tsv"
  recorded_layout=legacy
  recorded_agents=''
  if [[ ! -e "$metadata" && ! -L "$metadata" ]]; then
    if [[ -f "$manifest" ]] && { grep -Fqx -- "$MANAGED_LEDGER_HEADER" "$manifest" || awk -F '\t' -v root="$root" 'index($1, root "/.agents/") == 1 { found=1 } END { exit !found }' "$manifest"; }; then
      echo "error: managed installation metadata is missing: $metadata; restore it before install/remove" >&2
      return 1
    fi
    return 0
  fi
  [[ -f "$metadata" && ! -L "$metadata" && -f "$manifest" && ! -L "$manifest" ]] || {
    echo "error: managed installation needs regular manifest and metadata files: $metadata" >&2; return 1;
  }
  [[ "$(head -n 1 "$manifest")" == "$MANAGED_LEDGER_HEADER" ]] || {
    echo "error: managed ledger header is missing: $manifest" >&2; return 1;
  }
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *$'\t'* ]] || return 1
    key="${line%%$'\t'*}"
    value="${line#*$'\t'}"
    [[ -n "$key" && -n "$value" && "$value" != *$'\t'* && "$keys" != *"|$key|"* ]] || {
      echo "error: invalid or duplicate managed metadata field: $metadata" >&2; return 1;
    }
    keys+="$key|"
    count=$((count + 1))
    case "$key" in
      version) [[ "$value" == 1 ]] || return 1 ;;
      layout) [[ "$value" == managed ]] || return 1; recorded_layout="$value" ;;
      agents) [[ "$value" == /* && "$value" != *'|'* ]] || return 1; recorded_agents="$value" ;;
      target_root) [[ "$value" == "$root" ]] || return 1 ;;
      *) echo "error: unknown managed metadata field: $key" >&2; return 1 ;;
    esac
  done < "$metadata"
  [[ "$count" -eq 4 && "$keys" == *'|version|'* && "$keys" == *'|layout|'* && "$keys" == *'|agents|'* && "$keys" == *'|target_root|'* ]] || {
    echo "error: incomplete managed installation metadata: $metadata" >&2; return 1;
  }
}
