#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/../tooling/scripts/lib/paths.sh"
fail() { echo "error: $*" >&2; exit 1; }
usage() {
  cat <<'USAGE'
Usage: environment/profile.sh COMMAND --source DIR --destination DIR --config FILE --state FILE --cache DIR

Commands:
  init     Copy the example into a NEW source directory and initialize chezmoi (no apply)
  preview  Show the destination diff (no destination changes)
  status   Show destination drift (no destination changes)
  apply    Explicitly apply files; fail on conflicts instead of overwriting user edits

All five paths must be absolute; destination must already exist.
CHEZMOI_BIN may name an optional existing chezmoi binary. No downloads or package installs.
USAGE
}

[[ $# -gt 0 ]] || { usage; exit 0; }
command_name="$1"
shift
case "$command_name" in
  -h|--help) usage; exit 0 ;;
  init|preview|status|apply) ;;
  *) fail "unknown command: $command_name" ;;
esac

source_dir='' destination='' config='' state='' cache=''
while [[ $# -gt 0 ]]; do
  [[ $# -ge 2 ]] || fail "$1 requires a path"
  case "$1" in
    --source) source_dir="$2" ;;
    --destination) destination="$2" ;;
    --config) config="$2" ;;
    --state) state="$2" ;;
    --cache) cache="$2" ;;
    *) fail "unknown option: $1" ;;
  esac
  shift 2
done
for path in "$source_dir" "$destination" "$config" "$state" "$cache"; do
  [[ "$path" == /* && "$path" != / ]] || fail "all five paths must be explicit absolute paths other than /"
done
[[ -d "$destination" ]] || fail "destination directory must already exist: $destination"

# Keep machine-local files out of the checkout and all profile inputs away
# from the files being deployed. The destination may still be the whole home.
validate_profile_paths() {
  local selected path resolved resolved_source deployed_dir resolved_deployed
  deployed_dir="$destination/.config/dotagents-environment"
  resolved_deployed="$(resolve_path "$deployed_dir")" || fail "cannot resolve deployment directory: $deployed_dir"
  for selected in source_dir config state cache; do
    path="${!selected}"
    resolved="$(resolve_path "$path")" || fail "cannot resolve profile path: $path"
    if path_is_within "$deployed_dir" "$path" || path_is_within "$resolved_deployed" "$resolved" || path_is_within "$resolved" "$resolved_deployed"; then
      fail "profile path overlaps the deployment directory: $path"
    fi
    if [[ "$selected" == source_dir ]]; then
      resolved_source="$resolved"
    elif path_is_within "$source_dir" "$path" || path_is_within "$resolved_source" "$resolved"; then
      fail "config, state, and cache must be outside the source directory: $path"
    fi
  done
}
validate_profile_paths
chezmoi_bin="${CHEZMOI_BIN:-chezmoi}"
command -v "$chezmoi_bin" >/dev/null 2>&1 || fail "chezmoi is optional and not installed; see environment/README.md"

if [[ "$command_name" == init ]]; then
  [[ ! -e "$source_dir" && ! -L "$source_dir" ]] || fail "init requires a new source directory; existing source is preserved"
  mkdir -p "$(dirname "$source_dir")"
  mkdir "$source_dir"
  trap 'rmdir "$source_dir" 2>/dev/null || true' EXIT
  # A new source has no filesystem identity during preflight. Check again
  # before any machine-local path is created, including alternate spellings.
  validate_profile_paths
  # An explicit config avoids reading another chezmoi profile. Never truncate it.
  mkdir -p "$(dirname "$config")" "$(dirname "$state")" "$cache"
  if [[ ! -e "$config" && ! -L "$config" ]]; then
    (set -o noclobber; printf '%s\n' '# dotagents environment profile; no identity or secrets.' > "$config")
  fi
  cp -R "$SCRIPT_DIR/source/." "$source_dir"
  trap - EXIT
else
  [[ -d "$source_dir" ]] || fail "source does not exist; run init first"
  [[ -f "$config" ]] || fail "explicit config file does not exist; run init first"
fi

args=(
  --source "$source_dir" --destination "$destination" --config "$config"
  --persistent-state "$state" --cache "$cache" --working-tree "$source_dir"
  --mode file --no-pager --no-tty --use-builtin-diff --less-interactive --error-on-conflict
)
case "$command_name" in
  init) exec "$chezmoi_bin" "${args[@]}" --use-builtin-git=true init --config-path "$config" ;;
  preview) exec "$chezmoi_bin" "${args[@]}" diff ;;
  status) exec "$chezmoi_bin" "${args[@]}" status ;;
  apply) exec "$chezmoi_bin" "${args[@]}" apply ;;
esac
