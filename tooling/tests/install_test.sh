#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-test.XXXXXX")"
trap 'rm -r "$TEST_ROOT"' EXIT

fail() { echo "test failed: $*" >&2; exit 1; }
assert_link() { [[ -L "$1" && -e "$1" ]] || fail "expected live link: $1"; }

home_dir="$TEST_ROOT/home"
state_dir="$TEST_ROOT/state"
mkdir -p "$home_dir"

echo "scenario 1: clean global install"
DOTAGENTS_HOME="$home_dir" XDG_STATE_HOME="$state_dir" "$REPO_ROOT/tooling/scripts/install.sh" --global >/dev/null
assert_link "$home_dir/.agents"
assert_link "$home_dir/.claude/CLAUDE.md"
assert_link "$home_dir/.claude/settings.json"
assert_link "$home_dir/.claude/skills/product-development-workflow"
assert_link "$home_dir/.claude/skills/dotagents-promote"
assert_link "$home_dir/.codex/AGENTS.md"
assert_link "$home_dir/.gemini/GEMINI.md"
assert_link "$home_dir/.local/bin/dotagents-workflow"
assert_link "$home_dir/.agents/skills/product-development-workflow"
[[ -f "$home_dir/.claude/skills/product-development-workflow/references/claude-code.md" ]] || fail "Claude install does not expose Claude verification guidance"
[[ -f "$home_dir/.agents/skills/product-development-workflow/references/codex-cli.md" ]] || fail "Codex install does not expose Codex verification guidance"
[[ -f "$home_dir/.agents/skills/product-development-workflow/references/brief-template.md" ]] || fail "installed workflow does not expose the conditional Brief template"
[[ ! -e "$home_dir/.agents/skills/product-development-workflow/references/model-verification.md" ]] || fail "installed workflow still exposes the removed combined host guidance"
[[ -x "$home_dir/.local/bin/dotagents-workflow" ]] || fail "global workflow command is not executable"
"$home_dir/.local/bin/dotagents-workflow" --help >/dev/null
[[ "$(readlink "$home_dir/.claude/CLAUDE.md")" == "$REPO_ROOT/agents/adapters/claude/CLAUDE.md" ]] || fail "Claude adapter source was not updated"
[[ "$(readlink "$home_dir/.claude/settings.json")" == "$REPO_ROOT/agents/adapters/claude/settings.json" ]] || fail "Claude settings source was not updated"
jq -e '.hooks.PreToolUse' "$home_dir/.claude/settings.json" >/dev/null || fail "installed Claude settings do not register the commit hook"
[[ "$(readlink "$home_dir/.codex/AGENTS.md")" == "$REPO_ROOT/agents/adapters/codex/AGENTS.md" ]] || fail "Codex adapter source was not updated"
[[ "$(readlink "$home_dir/.gemini/GEMINI.md")" == "$REPO_ROOT/agents/adapters/gemini/GEMINI.md" ]] || fail "Gemini adapter source was not updated"
[[ "$(readlink "$home_dir/.claude/skills/product-development-workflow")" == "$REPO_ROOT/agents/skills/owned/product-development-workflow" ]] || fail "Claude workflow skill source is incorrect"
[[ "$(readlink "$home_dir/.claude/skills/dotagents-promote")" == "$REPO_ROOT/agents/skills/owned/dotagents-promote" ]] || fail "Claude promote skill source is incorrect"
[[ "$(readlink "$home_dir/.local/bin/dotagents-workflow")" == "$REPO_ROOT/tooling/scripts/workflow.sh" ]] || fail "workflow command source is incorrect"

echo "scenario 2: repeated install is idempotent"
DOTAGENTS_HOME="$home_dir" XDG_STATE_HOME="$state_dir" "$REPO_ROOT/tooling/scripts/install.sh" --global >/dev/null
assert_link "$home_dir/.codex/AGENTS.md"

echo "scenario 3: existing file blocks install without changes"
conflict_home="$TEST_ROOT/conflict-home"
mkdir -p "$conflict_home/.claude"
printf '%s\n' 'user content' > "$conflict_home/.claude/CLAUDE.md"
if DOTAGENTS_HOME="$conflict_home" XDG_STATE_HOME="$TEST_ROOT/conflict-state" "$REPO_ROOT/tooling/scripts/install.sh" --global >/dev/null 2>&1; then
  fail "conflicting install should fail"
fi
grep -q 'user content' "$conflict_home/.claude/CLAUDE.md" || fail "conflicting file changed"
[[ ! -e "$conflict_home/.agents" ]] || fail "partial install occurred"

echo "scenario 4: reinstall repairs links after repository move"
moved_repo="$TEST_ROOT/moved-dotagents"
cp -R "$REPO_ROOT" "$moved_repo"
moved_repo="$(cd "$moved_repo" && pwd -P)"
DOTAGENTS_HOME="$home_dir" XDG_STATE_HOME="$state_dir" "$moved_repo/tooling/scripts/install.sh" --global >/dev/null
[[ "$(readlink "$home_dir/.agents")" == "$moved_repo/agents" ]] || fail "moved source was not applied"
[[ "$(readlink "$home_dir/.local/bin/dotagents-workflow")" == "$moved_repo/tooling/scripts/workflow.sh" ]] || fail "moved workflow command was not applied"

echo "scenario 5: user-replaced file is preserved during uninstall"
modified_home="$TEST_ROOT/modified-home"
modified_state="$TEST_ROOT/modified-state"
mkdir -p "$modified_home"
DOTAGENTS_HOME="$modified_home" XDG_STATE_HOME="$modified_state" "$REPO_ROOT/tooling/scripts/install.sh" --global >/dev/null
unlink "$modified_home/.gemini/GEMINI.md"
printf '%s\n' 'user replacement' > "$modified_home/.gemini/GEMINI.md"
DOTAGENTS_HOME="$modified_home" XDG_STATE_HOME="$modified_state" "$REPO_ROOT/tooling/scripts/uninstall.sh" --global >/dev/null 2>&1
grep -q 'user replacement' "$modified_home/.gemini/GEMINI.md" || fail "user-replaced file was removed"
[[ ! -e "$modified_home/.claude/skills/product-development-workflow" ]] || fail "workflow skill link was not removed"
[[ ! -e "$modified_home/.claude/skills/dotagents-promote" ]] || fail "promote skill link was not removed"
[[ ! -e "$modified_home/.local/bin/dotagents-workflow" ]] || fail "workflow command link was not removed"

echo "scenario 6: force backup is restored on uninstall"
backup_home="$TEST_ROOT/backup-home"
backup_state="$TEST_ROOT/backup-state"
mkdir -p "$backup_home/.codex"
printf '%s\n' 'preserve me' > "$backup_home/.codex/AGENTS.md"
DOTAGENTS_HOME="$backup_home" XDG_STATE_HOME="$backup_state" "$REPO_ROOT/tooling/scripts/install.sh" --global --force >/dev/null
assert_link "$backup_home/.codex/AGENTS.md"
DOTAGENTS_HOME="$backup_home" XDG_STATE_HOME="$backup_state" "$REPO_ROOT/tooling/scripts/uninstall.sh" --global >/dev/null
[[ -f "$backup_home/.codex/AGENTS.md" ]] || fail "backup was not restored"
grep -q 'preserve me' "$backup_home/.codex/AGENTS.md" || fail "restored content changed"

echo "scenario 7: clean project install uses reorganized adapters"
project_dir="$TEST_ROOT/project"
mkdir -p "$project_dir"
"$REPO_ROOT/tooling/scripts/install.sh" --project "$project_dir" >/dev/null
assert_link "$project_dir/.agents"
assert_link "$project_dir/AGENTS.md"
assert_link "$project_dir/CLAUDE.md"
assert_link "$project_dir/.claude/skills/product-development-workflow"
assert_link "$project_dir/.claude/skills/dotagents-promote"
assert_link "$project_dir/GEMINI.md"
assert_link "$project_dir/.dotagents/bin/dotagents-workflow"
assert_link "$project_dir/.agents/skills/product-development-workflow"
[[ -f "$project_dir/.claude/skills/product-development-workflow/references/claude-code.md" ]] || fail "project Claude install does not expose Claude verification guidance"
[[ -f "$project_dir/.agents/skills/product-development-workflow/references/codex-cli.md" ]] || fail "project Codex install does not expose Codex verification guidance"
[[ -f "$project_dir/.agents/skills/product-development-workflow/references/brief-template.md" ]] || fail "project workflow does not expose the conditional Brief template"
[[ -x "$project_dir/.dotagents/bin/dotagents-workflow" ]] || fail "project workflow command is not executable"
[[ "$(readlink "$project_dir/AGENTS.md")" == "$REPO_ROOT/agents/adapters/codex/AGENTS.md" ]] || fail "project Codex adapter source is incorrect"
[[ "$(readlink "$project_dir/CLAUDE.md")" == "$REPO_ROOT/agents/adapters/claude/CLAUDE.md" ]] || fail "project Claude adapter source is incorrect"
[[ "$(readlink "$project_dir/GEMINI.md")" == "$REPO_ROOT/agents/adapters/gemini/GEMINI.md" ]] || fail "project Gemini adapter source is incorrect"
[[ "$(readlink "$project_dir/.dotagents/bin/dotagents-workflow")" == "$REPO_ROOT/tooling/scripts/workflow.sh" ]] || fail "project workflow command source is incorrect"
"$project_dir/.dotagents/bin/dotagents-workflow" start --project "$project_dir" --run installed-entrypoint --scope standard >/dev/null
entry_status="$("$project_dir/.dotagents/bin/dotagents-workflow" status --project "$project_dir" --run installed-entrypoint)"
[[ "$entry_status" == *"current_stage: 1"* ]] || fail "installed workflow command did not run a start/status flow"

echo "scenario 8: reinstall repairs legacy internal adapter paths"
legacy_home="$TEST_ROOT/legacy-home"
legacy_state="$TEST_ROOT/legacy-state"
legacy_target="$legacy_home/.codex/AGENTS.md"
legacy_source="$REPO_ROOT/codex/AGENTS.md"
mkdir -p "$(dirname "$legacy_target")" "$legacy_state/dotagents"
ln -s "$legacy_source" "$legacy_target"
printf '%s\t%s\t-\n' "$legacy_target" "$legacy_source" > "$legacy_state/dotagents/install.tsv"
DOTAGENTS_HOME="$legacy_home" XDG_STATE_HOME="$legacy_state" "$REPO_ROOT/tooling/scripts/install.sh" --global >/dev/null
[[ "$(readlink "$legacy_target")" == "$REPO_ROOT/agents/adapters/codex/AGENTS.md" ]] || fail "legacy adapter link was not repaired"

echo "scenario 9: parent path hazards fail before making partial changes"
unsafe_global="$TEST_ROOT/unsafe-global"
unsafe_global_state="$TEST_ROOT/unsafe-global-state"
mkdir -p "$unsafe_global/.claude"
printf '%s\n' 'not a directory' > "$unsafe_global/.claude/skills"
if DOTAGENTS_HOME="$unsafe_global" XDG_STATE_HOME="$unsafe_global_state" "$REPO_ROOT/tooling/scripts/install.sh" --global >/dev/null 2>&1; then
  fail "global install should reject a non-directory parent"
fi
[[ ! -e "$unsafe_global/.agents" ]] || fail "global parent validation left partial links"
[[ ! -e "$unsafe_global/.claude/CLAUDE.md" ]] || fail "global parent validation left a partial adapter"

for unsafe_parent in .claude .dotagents; do
  unsafe_project="$TEST_ROOT/unsafe-${unsafe_parent#.}"
  outside_parent="$TEST_ROOT/outside-${unsafe_parent#.}"
  mkdir -p "$unsafe_project" "$outside_parent"
  ln -s "$outside_parent" "$unsafe_project/$unsafe_parent"
  if "$REPO_ROOT/tooling/scripts/install.sh" --project "$unsafe_project" >/dev/null 2>&1; then
    fail "project install should reject symlinked parent: $unsafe_parent"
  fi
  [[ ! -e "$unsafe_project/.agents" ]] || fail "unsafe project install made partial changes: $unsafe_parent"
  if [[ "$unsafe_parent" == ".claude" ]]; then
    [[ ! -e "$outside_parent/skills/product-development-workflow" ]] || fail "project install escaped through .claude"
  else
    [[ ! -e "$outside_parent/bin/dotagents-workflow" ]] || fail "project install escaped through .dotagents"
  fi
done

echo "All install scenarios passed."
