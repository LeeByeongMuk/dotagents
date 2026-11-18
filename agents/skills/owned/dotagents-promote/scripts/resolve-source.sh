#!/usr/bin/env bash
set -euo pipefail

fail() { echo "error: $*" >&2; exit 1; }

# Follow the installed skill directory to its checkout before reading metadata.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$script_dir/../../../../.." && pwd -P)"
[[ -f "$repo/dotagents.toml" && -f "$repo/agents/rules/git.md" ]] || fail 'cannot locate the dotagents checkout that provides this skill'
[[ "$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)" == "$repo" ]] || fail "expected a dotagents Git checkout at $repo"
source "$repo/tooling/scripts/lib/install-layout.sh"

target_root="${DOTAGENTS_HOME:-$HOME}"
agents_target="$target_root/.agents"
manifest="${XDG_STATE_HOME:-$target_root/.local/state}/dotagents/install.tsv"
read_install_layout "$manifest" "$target_root" || fail 'restore the global installation ledger and metadata before promoting'
if [[ "$recorded_layout" == managed ]]; then
  [[ "$recorded_agents" -ef "$repo/agents" ]] || fail 'managed installation records a different dotagents checkout'
  managed_target_parent "$target_root" "$agents_target/rules" || fail 'managed installation has an unsafe shared rules parent'
  [[ -L "$agents_target/rules" && "$agents_target/rules" -ef "$repo/agents/rules" ]] || fail 'restore the managed shared rules link before promoting'
else
  [[ -L "$agents_target" && "$agents_target" -ef "$repo/agents" ]] || fail 'expected the legacy .agents link to this skill checkout or a managed installation record'
fi

git_dir="$(git -C "$repo" rev-parse --absolute-git-dir)"
common_dir="$(cd "$repo" && cd "$(git rev-parse --git-common-dir)" && pwd -P)"
[[ "$git_dir" -ef "$common_dir" && "$(git -C "$repo" symbolic-ref --quiet --short HEAD)" == main ]] || fail "expected the installed primary checkout on main: $repo"
printf '%s\n' "$repo"
