#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-test.XXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"
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
assert_link "$home_dir/.claude/skills/fsd-refactor"
assert_link "$home_dir/.agents/skills/fsd-refactor"
[[ -f "$home_dir/.agents/skills/fsd-refactor/agents/openai.yaml" ]] || fail "global FSD discovery does not expose metadata"
assert_link "$home_dir/.claude/skills/dotagents-promote"
assert_link "$home_dir/.claude/skills/usage-guide"
assert_link "$home_dir/.codex/AGENTS.md"
assert_link "$home_dir/.codex/hooks.json"
assert_link "$home_dir/.gemini/GEMINI.md"
assert_link "$home_dir/.agents/skills/product-development-workflow"
[[ -f "$home_dir/.claude/skills/product-development-workflow/references/claude-code.md" ]] || fail "Claude install does not expose Claude verification guidance"
[[ -f "$home_dir/.agents/skills/product-development-workflow/references/codex-cli.md" ]] || fail "Codex install does not expose Codex verification guidance"
[[ -f "$home_dir/.agents/skills/product-development-workflow/references/brief-template.md" ]] || fail "installed workflow does not expose the conditional Brief template"
[[ ! -e "$home_dir/.agents/skills/product-development-workflow/references/model-verification.md" ]] || fail "installed workflow still exposes the removed combined host guidance"
[[ "$(readlink "$home_dir/.claude/CLAUDE.md")" == "$REPO_ROOT/dist/claude/CLAUDE.md" ]] || fail "Claude adapter source was not updated"
[[ "$(readlink "$home_dir/.claude/settings.json")" == "$REPO_ROOT/agents/adapters/claude/settings.json" ]] || fail "Claude settings source was not updated"
jq -e '.hooks.PreToolUse' "$home_dir/.claude/settings.json" >/dev/null || fail "installed Claude settings do not register the commit hook"
jq -e '.hooks.PreToolUse' "$home_dir/.codex/hooks.json" >/dev/null || fail "installed Codex hooks do not register the commit hook"
[[ "$(readlink "$home_dir/.codex/AGENTS.md")" == "$REPO_ROOT/dist/codex/AGENTS.md" ]] || fail "Codex adapter source was not updated"
[[ "$(readlink "$home_dir/.gemini/GEMINI.md")" == "$REPO_ROOT/dist/gemini/GEMINI.md" ]] || fail "Gemini adapter source was not updated"
[[ "$(readlink "$home_dir/.claude/skills/product-development-workflow")" == "$REPO_ROOT/agents/skills/owned/product-development-workflow" ]] || fail "Claude workflow skill source is incorrect"
[[ "$(readlink "$home_dir/.claude/skills/fsd-refactor")" == "$REPO_ROOT/agents/skills/owned/fsd-refactor" ]] || fail "Claude FSD skill source is incorrect"
[[ "$(readlink "$home_dir/.claude/skills/dotagents-promote")" == "$REPO_ROOT/agents/skills/owned/dotagents-promote" ]] || fail "Claude promote skill source is incorrect"
[[ "$(readlink "$home_dir/.claude/skills/usage-guide")" == "$REPO_ROOT/agents/skills/owned/usage-guide" ]] || fail "Claude usage guide skill source is incorrect"

echo "scenario 2: repeated install is idempotent"
DOTAGENTS_HOME="$home_dir" XDG_STATE_HOME="$state_dir" "$REPO_ROOT/tooling/scripts/install.sh" --global >/dev/null
assert_link "$home_dir/.codex/AGENTS.md"

assert_link "$home_dir/.claude/skills/fsd-refactor"
[[ "$(readlink "$home_dir/.claude/skills/fsd-refactor")" == "$REPO_ROOT/agents/skills/owned/fsd-refactor" ]] || fail "repeated install changed the FSD source"

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

assert_link "$home_dir/.claude/skills/fsd-refactor"
assert_link "$home_dir/.agents/skills/fsd-refactor"
[[ "$(readlink "$home_dir/.claude/skills/fsd-refactor")" == "$moved_repo/agents/skills/owned/fsd-refactor" ]] || fail "reinstall did not repair the FSD source after repository move"

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
[[ ! -e "$modified_home/.claude/skills/fsd-refactor" && ! -L "$modified_home/.claude/skills/fsd-refactor" ]] || fail "FSD skill link was not removed"
[[ ! -e "$modified_home/.claude/skills/dotagents-promote" ]] || fail "promote skill link was not removed"
[[ ! -e "$modified_home/.claude/skills/usage-guide" ]] || fail "usage guide skill link was not removed"

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
assert_link "$project_dir/.claude/skills/fsd-refactor"
assert_link "$project_dir/.agents/skills/fsd-refactor"
[[ -f "$project_dir/.agents/skills/fsd-refactor/agents/openai.yaml" ]] || fail "project FSD discovery does not expose metadata"
[[ "$(readlink "$project_dir/.claude/skills/fsd-refactor")" == "$REPO_ROOT/agents/skills/owned/fsd-refactor" ]] || fail "project Claude FSD skill source is incorrect"
assert_link "$project_dir/.claude/skills/dotagents-promote"
assert_link "$project_dir/.claude/skills/usage-guide"
assert_link "$project_dir/GEMINI.md"
assert_link "$project_dir/.agents/skills/product-development-workflow"
[[ -f "$project_dir/.claude/skills/product-development-workflow/references/claude-code.md" ]] || fail "project Claude install does not expose Claude verification guidance"
[[ -f "$project_dir/.agents/skills/product-development-workflow/references/codex-cli.md" ]] || fail "project Codex install does not expose Codex verification guidance"
[[ -f "$project_dir/.agents/skills/product-development-workflow/references/brief-template.md" ]] || fail "project workflow does not expose the conditional Brief template"
[[ "$(readlink "$project_dir/AGENTS.md")" == "$REPO_ROOT/dist/codex/AGENTS.md" ]] || fail "project Codex adapter source is incorrect"
[[ "$(readlink "$project_dir/CLAUDE.md")" == "$REPO_ROOT/dist/claude/CLAUDE.md" ]] || fail "project Claude adapter source is incorrect"
[[ "$(readlink "$project_dir/GEMINI.md")" == "$REPO_ROOT/dist/gemini/GEMINI.md" ]] || fail "project Gemini adapter source is incorrect"

# Install from the original checkout again so the reinstall below repairs
# existing links even when an earlier step removed them.
"$REPO_ROOT/tooling/scripts/install.sh" --project "$project_dir" >/dev/null
"$moved_repo/tooling/scripts/install.sh" --project "$project_dir" >/dev/null
assert_link "$project_dir/.agents/skills/fsd-refactor"
[[ "$(readlink "$project_dir/.claude/skills/fsd-refactor")" == "$moved_repo/agents/skills/owned/fsd-refactor" ]] || fail "project reinstall did not repair the FSD source"
"$moved_repo/tooling/scripts/uninstall.sh" --project "$project_dir" >/dev/null
[[ ! -e "$project_dir/.claude/skills/fsd-refactor" && ! -L "$project_dir/.claude/skills/fsd-refactor" ]] || fail "project FSD link was not removed"

echo "scenario 8: reinstall repairs legacy internal adapter paths"
legacy_home="$TEST_ROOT/legacy-home"
legacy_state="$TEST_ROOT/legacy-state"
legacy_target="$legacy_home/.codex/AGENTS.md"
legacy_source="$REPO_ROOT/codex/AGENTS.md"
mkdir -p "$(dirname "$legacy_target")" "$legacy_state/dotagents"
ln -s "$legacy_source" "$legacy_target"
printf '%s\t%s\t-\n' "$legacy_target" "$legacy_source" > "$legacy_state/dotagents/install.tsv"
DOTAGENTS_HOME="$legacy_home" XDG_STATE_HOME="$legacy_state" "$REPO_ROOT/tooling/scripts/install.sh" --global >/dev/null
[[ "$(readlink "$legacy_target")" == "$REPO_ROOT/dist/codex/AGENTS.md" ]] || fail "legacy adapter link was not repaired"

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

unsafe_project="$TEST_ROOT/unsafe-claude"
outside_parent="$TEST_ROOT/outside-claude"
mkdir -p "$unsafe_project" "$outside_parent"
ln -s "$outside_parent" "$unsafe_project/.claude"
if "$REPO_ROOT/tooling/scripts/install.sh" --project "$unsafe_project" >/dev/null 2>&1; then
  fail "project install should reject a symlinked .claude parent"
fi
[[ ! -e "$unsafe_project/.agents" ]] || fail "unsafe project install made partial changes"
[[ ! -e "$outside_parent/skills/product-development-workflow" ]] || fail "project install escaped through .claude"

echo "scenario 10: a global install into the real home runs only from main in the primary checkout"
guard_repo="$TEST_ROOT/guard-repo"
guard_home="$TEST_ROOT/guard-home"
mkdir -p "$guard_repo" "$guard_home"
cp -R "$REPO_ROOT"/. "$guard_repo"
rm -rf "$guard_repo/.git"
guard_repo="$(cd "$guard_repo" && pwd -P)"
git -C "$guard_repo" init -q
git -C "$guard_repo" symbolic-ref HEAD refs/heads/feature
guard_install() { env -u DOTAGENTS_HOME HOME="$guard_home" XDG_STATE_HOME="$guard_home/state" "$1/tooling/scripts/install.sh" --global; }
if guard_install "$guard_repo" >/dev/null 2>&1; then
  fail "global install ran from a branch other than main"
fi
[[ ! -e "$guard_home/.agents" ]] || fail "refused global install still created links"
guard_output="$(env -u DOTAGENTS_HOME HOME="$guard_home" XDG_STATE_HOME="$guard_home/state" "$guard_repo/tooling/scripts/install.sh" --dry-run --global)"
grep -q 'a real run would refuse' <<< "$guard_output" || fail "dry run did not warn about the branch"
git -C "$guard_repo" symbolic-ref HEAD refs/heads/main
git -C "$guard_repo" -c user.name=t -c user.email=t@example.com -c core.hooksPath=/dev/null add -A
git -C "$guard_repo" -c user.name=t -c user.email=t@example.com -c core.hooksPath=/dev/null commit -q -m 'chore: seed guard repository'
git -C "$guard_repo" worktree add -q --detach "$TEST_ROOT/guard-worktree"
if guard_output="$(guard_install "$TEST_ROOT/guard-worktree" 2>&1)"; then
  fail "global install ran from a linked worktree"
fi
grep -q 'linked worktree' <<< "$guard_output" || fail "worktree refusal did not name the cause"
[[ ! -e "$guard_home/.agents" ]] || fail "worktree install created links"
guard_install "$guard_repo" >/dev/null || fail "global install from main was refused"
assert_link "$guard_home/.agents"

echo "scenario 11: entries dropped from the install list are removed on reinstall"
retired_home="$TEST_ROOT/retired-home"
retired_state="$TEST_ROOT/retired-state"
mkdir -p "$retired_home/.local/bin" "$retired_home/.config"
DOTAGENTS_HOME="$retired_home" XDG_STATE_HOME="$retired_state" "$REPO_ROOT/tooling/scripts/install.sh" --global >/dev/null
retired_manifest="$retired_state/dotagents/install.tsv"
ln -s "$REPO_ROOT/tooling/scripts/doctor.sh" "$retired_home/.local/bin/dotagents-retired"
printf '%s\t%s\t%s\n' "$retired_home/.local/bin/dotagents-retired" "$REPO_ROOT/tooling/scripts/doctor.sh" '-' >> "$retired_manifest"
printf '%s\n' 'original config' > "$retired_home/.config/tool.backup"
ln -s "$REPO_ROOT/README.md" "$retired_home/.config/tool"
printf '%s\t%s\t%s\n' "$retired_home/.config/tool" "$REPO_ROOT/README.md" "$retired_home/.config/tool.backup" >> "$retired_manifest"
DOTAGENTS_HOME="$retired_home" XDG_STATE_HOME="$retired_state" "$REPO_ROOT/tooling/scripts/install.sh" --global >/dev/null
[[ ! -e "$retired_home/.local/bin/dotagents-retired" && ! -L "$retired_home/.local/bin/dotagents-retired" ]] || fail "retired link was not removed"
grep -q 'original config' "$retired_home/.config/tool" || fail "retired entry backup was not restored"
! grep -Fq 'dotagents-retired' "$retired_manifest" || fail "retired entry stayed in the manifest"
assert_link "$retired_home/.agents"

failure_bin="$TEST_ROOT/failure-bin"
mkdir -p "$failure_bin"
export INSTALL_TEST_REAL_LN="$(command -v ln)"
export INSTALL_TEST_REAL_MV="$(command -v mv)"
cat > "$failure_bin/ln" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${INSTALL_TEST_FAIL_TARGET:-}" == "${@: -1}" ]]; then
  if [[ "${INSTALL_TEST_SIGNAL:-error}" != "error" ]]; then
    "$INSTALL_TEST_REAL_LN" "$@"
    kill -s "$INSTALL_TEST_SIGNAL" "$PPID"
    exit 0
  fi
  exit 73
fi
exec "$INSTALL_TEST_REAL_LN" "$@"
EOF
cat > "$failure_bin/mv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == *.transaction.*/install.tsv && "${INSTALL_TEST_FAIL_MANIFEST:-}" == "$2" ]]; then
  if [[ "${INSTALL_TEST_SIGNAL:-error}" != "error" ]]; then
    "$INSTALL_TEST_REAL_MV" "$@"
    kill -s "$INSTALL_TEST_SIGNAL" "$PPID"
    exit 0
  fi
  exit 73
fi
exec "$INSTALL_TEST_REAL_MV" "$@"
EOF
cat > "$failure_bin/date" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '20000101000000'
EOF
chmod +x "$failure_bin/ln" "$failure_bin/mv" "$failure_bin/date"

echo "scenario 12: failed or interrupted forced installs restore originals before retry"
for interruption in error TERM INT; do
  failed_project="$TEST_ROOT/failed-project-$interruption"
  mkdir -p "$failed_project"
  printf '%s\n' 'original project rules' > "$failed_project/AGENTS.md"
  ln -s "$TEST_ROOT/missing-original" "$failed_project/CLAUDE.md"
  if PATH="$failure_bin:$PATH" INSTALL_TEST_FAIL_TARGET="$failed_project/CLAUDE.md" INSTALL_TEST_SIGNAL="$interruption" \
    "$REPO_ROOT/tooling/scripts/install.sh" --project "$failed_project" --force >/dev/null 2>&1; then
    fail "injected $interruption should stop the install"
  fi
  [[ ! -L "$failed_project/AGENTS.md" ]] || fail "$interruption left the new AGENTS link"
  grep -q 'original project rules' "$failed_project/AGENTS.md" || fail "$interruption lost the original AGENTS file"
  [[ "$(readlink "$failed_project/CLAUDE.md")" == "$TEST_ROOT/missing-original" ]] || fail "$interruption lost the original dangling link"
  [[ ! -e "$failed_project/.agents" && ! -L "$failed_project/.agents" ]] || fail "$interruption left a partial install"
  [[ ! -e "$failed_project/.dotagents-install.tsv" ]] || fail "$interruption committed a partial manifest"
  ! compgen -G "$failed_project/*.dotagents-backup.*" >/dev/null || fail "$interruption left orphaned backups"
  ! compgen -G "$failed_project/.dotagents-install.tsv.transaction.*" >/dev/null || fail "$interruption left transaction files"
  "$REPO_ROOT/tooling/scripts/install.sh" --project "$failed_project" --force >/dev/null
  "$REPO_ROOT/tooling/scripts/uninstall.sh" --project "$failed_project" >/dev/null
  grep -q 'original project rules' "$failed_project/AGENTS.md" || fail "$interruption retry lost the original backup record"
done

echo "scenario 13: a failed upgrade preserves managed links, the manifest, and existing backups"
upgrade_project="$TEST_ROOT/failed-upgrade"
mkdir -p "$upgrade_project"
printf '%s\n' 'rules before the first install' > "$upgrade_project/AGENTS.md"
"$REPO_ROOT/tooling/scripts/install.sh" --project "$upgrade_project" --force >/dev/null
cp "$upgrade_project/.dotagents-install.tsv" "$TEST_ROOT/upgrade-manifest"
upgrade_backup="$(awk -F '\t' -v target="$upgrade_project/AGENTS.md" '$1 == target { print $3 }' "$TEST_ROOT/upgrade-manifest")"
if PATH="$failure_bin:$PATH" INSTALL_TEST_FAIL_TARGET="$upgrade_project/CLAUDE.md" \
  "$moved_repo/tooling/scripts/install.sh" --project "$upgrade_project" >/dev/null 2>&1; then
  fail "injected upgrade failure should stop the install"
fi
cmp -s "$upgrade_project/.dotagents-install.tsv" "$TEST_ROOT/upgrade-manifest" || fail "failed upgrade changed the previous manifest"
while IFS=$'\t' read -r target source _; do
  [[ "$(readlink "$target")" == "$source" ]] || fail "failed upgrade did not restore managed link: $target"
done < "$TEST_ROOT/upgrade-manifest"
grep -q 'rules before the first install' "$upgrade_backup" || fail "failed upgrade changed an existing backup"
! compgen -G "$upgrade_project/.dotagents-install.tsv.transaction.*" >/dev/null || fail "failed upgrade left transaction files"
"$moved_repo/tooling/scripts/install.sh" --project "$upgrade_project" >/dev/null
"$moved_repo/tooling/scripts/uninstall.sh" --project "$upgrade_project" >/dev/null
grep -q 'rules before the first install' "$upgrade_project/AGENTS.md" || fail "upgrade retry lost the original backup record"

echo "scenario 14: manifest commit failure reverses retired-link removals and backup restores"
retired_project="$TEST_ROOT/failed-retirement"
mkdir -p "$retired_project"
"$REPO_ROOT/tooling/scripts/install.sh" --project "$retired_project" >/dev/null
retired_target="$retired_project/retired-config"
retired_backup="$retired_project/retired-config.backup"
ln -s "$REPO_ROOT/README.md" "$retired_target"
printf '%s\n' 'original retired config' > "$retired_backup"
printf '%s\t%s\t%s\n' "$retired_target" "$REPO_ROOT/README.md" "$retired_backup" >> "$retired_project/.dotagents-install.tsv"
cp "$retired_project/.dotagents-install.tsv" "$TEST_ROOT/retirement-manifest"
for interruption in error TERM; do
  if PATH="$failure_bin:$PATH" INSTALL_TEST_FAIL_MANIFEST="$retired_project/.dotagents-install.tsv" INSTALL_TEST_SIGNAL="$interruption" \
    "$REPO_ROOT/tooling/scripts/install.sh" --project "$retired_project" >/dev/null 2>&1; then
    fail "injected manifest $interruption should stop the install"
  fi
  cmp -s "$retired_project/.dotagents-install.tsv" "$TEST_ROOT/retirement-manifest" || fail "failed retirement changed the previous manifest"
  [[ "$(readlink "$retired_target")" == "$REPO_ROOT/README.md" ]] || fail "failed retirement did not restore the retired link"
  grep -q 'original retired config' "$retired_backup" || fail "failed retirement did not put the restored backup back"
  ! compgen -G "$retired_project/.dotagents-install.tsv.transaction.*" >/dev/null || fail "failed retirement left transaction files"
done
"$REPO_ROOT/tooling/scripts/install.sh" --project "$retired_project" >/dev/null
grep -q 'original retired config' "$retired_target" || fail "retirement retry did not restore the backup"

echo "scenario 15: rollback preserves an existing backup with the same timestamp"
collision_project="$TEST_ROOT/backup-collision"
mkdir -p "$collision_project"
printf '%s\n' 'current project rules' > "$collision_project/AGENTS.md"
collision_backup="$collision_project/AGENTS.md.dotagents-backup.20000101000000"
printf '%s\n' 'older project rules' > "$collision_backup"
if PATH="$failure_bin:$PATH" INSTALL_TEST_FAIL_TARGET="$collision_project/CLAUDE.md" \
  "$REPO_ROOT/tooling/scripts/install.sh" --project "$collision_project" --force >/dev/null 2>&1; then
  fail "injected failure with a backup collision should stop the install"
fi
grep -q 'current project rules' "$collision_project/AGENTS.md" || fail "backup collision lost the current original"
grep -q 'older project rules' "$collision_backup" || fail "backup collision overwrote an older backup"
[[ ! -e "$collision_backup.1" ]] || fail "backup collision left an orphaned backup"

echo "All install scenarios passed."
