#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-test.XXXXXX")"
trap 'rm -r "$TEST_ROOT"' EXIT

fail() { echo "test failed: $*" >&2; exit 1; }
assert_link() { [[ -L "$1" && -e "$1" ]] || fail "expected live link: $1"; }

home_dir="$TEST_ROOT/home"
state_dir="$TEST_ROOT/state"
mkdir -p "$home_dir"

echo "scenario 1: clean global install"
DOTAGENTS_HOME="$home_dir" XDG_STATE_HOME="$state_dir" "$REPO_ROOT/scripts/install.sh" --global >/dev/null
assert_link "$home_dir/.agents"
assert_link "$home_dir/.claude/CLAUDE.md"

echo "scenario 2: repeated install is idempotent"
DOTAGENTS_HOME="$home_dir" XDG_STATE_HOME="$state_dir" "$REPO_ROOT/scripts/install.sh" --global >/dev/null
assert_link "$home_dir/.codex/AGENTS.md"

echo "scenario 3: existing file blocks install without changes"
conflict_home="$TEST_ROOT/conflict-home"
mkdir -p "$conflict_home/.claude"
printf '%s\n' 'user content' > "$conflict_home/.claude/CLAUDE.md"
if DOTAGENTS_HOME="$conflict_home" XDG_STATE_HOME="$TEST_ROOT/conflict-state" "$REPO_ROOT/scripts/install.sh" --global >/dev/null 2>&1; then
  fail "conflicting install should fail"
fi
grep -q 'user content' "$conflict_home/.claude/CLAUDE.md" || fail "conflicting file changed"
[[ ! -e "$conflict_home/.agents" ]] || fail "partial install occurred"

echo "scenario 4: reinstall repairs links after repository move"
moved_repo="$TEST_ROOT/moved-dotagents"
cp -R "$REPO_ROOT" "$moved_repo"
moved_repo="$(cd "$moved_repo" && pwd -P)"
DOTAGENTS_HOME="$home_dir" XDG_STATE_HOME="$state_dir" "$moved_repo/scripts/install.sh" --global >/dev/null
[[ "$(readlink "$home_dir/.agents")" == "$moved_repo/agents" ]] || fail "moved source was not applied"

echo "scenario 5: user-replaced file is preserved during uninstall"
modified_home="$TEST_ROOT/modified-home"
modified_state="$TEST_ROOT/modified-state"
mkdir -p "$modified_home"
DOTAGENTS_HOME="$modified_home" XDG_STATE_HOME="$modified_state" "$REPO_ROOT/scripts/install.sh" --global >/dev/null
unlink "$modified_home/.gemini/GEMINI.md"
printf '%s\n' 'user replacement' > "$modified_home/.gemini/GEMINI.md"
DOTAGENTS_HOME="$modified_home" XDG_STATE_HOME="$modified_state" "$REPO_ROOT/scripts/uninstall.sh" --global >/dev/null 2>&1
grep -q 'user replacement' "$modified_home/.gemini/GEMINI.md" || fail "user-replaced file was removed"

echo "scenario 6: force backup is restored on uninstall"
backup_home="$TEST_ROOT/backup-home"
backup_state="$TEST_ROOT/backup-state"
mkdir -p "$backup_home/.codex"
printf '%s\n' 'preserve me' > "$backup_home/.codex/AGENTS.md"
DOTAGENTS_HOME="$backup_home" XDG_STATE_HOME="$backup_state" "$REPO_ROOT/scripts/install.sh" --global --force >/dev/null
assert_link "$backup_home/.codex/AGENTS.md"
DOTAGENTS_HOME="$backup_home" XDG_STATE_HOME="$backup_state" "$REPO_ROOT/scripts/uninstall.sh" --global >/dev/null
[[ -f "$backup_home/.codex/AGENTS.md" ]] || fail "backup was not restored"
grep -q 'preserve me' "$backup_home/.codex/AGENTS.md" || fail "restored content changed"

echo "All install scenarios passed."
