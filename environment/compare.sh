#!/usr/bin/env bash
# Bounded, destructive-to-TEMPORARY-fixtures-only comparison; never applies to HOME.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
chezmoi_bin="${CHEZMOI_BIN:-chezmoi}"
command -v "$chezmoi_bin" >/dev/null 2>&1 || { echo 'error: prepare an optional chezmoi binary first' >&2; exit 1; }
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-deployment-compare.XXXXXX")"
trap 'rm -r "$TEST_ROOT"' EXIT
fail() { echo "comparison failed: $*" >&2; exit 1; }
expect_failure() { if "$@" > "$TEST_ROOT/expected-error" 2>&1; then fail 'expected a nonzero exit'; fi; }
printf 'Engine: %s\n' "$("$chezmoi_bin" --version)"

# The current installer retains its full AI inventory. Compare just two identical
# JSON payloads at the same relative paths; do not pretend this is a full migration.
link_repo="$TEST_ROOT/link-repo"
mkdir -p "$link_repo/tooling/scripts" "$TEST_ROOT/link-home/.claude" "$TEST_ROOT/link-state"
cp -R "$REPO_ROOT/agents" "$REPO_ROOT/dist" "$link_repo/"
cp "$REPO_ROOT/tooling/scripts/install.sh" "$REPO_ROOT/tooling/scripts/uninstall.sh" "$link_repo/tooling/scripts/"
printf '%s\n' '{"fixture": "v1"}' > "$link_repo/agents/adapters/claude/settings.json"
printf '%s\n' '{"fixture": "v1"}' > "$link_repo/agents/adapters/codex/hooks.json"
link_install() {
  DOTAGENTS_HOME="$TEST_ROOT/link-home" XDG_STATE_HOME="$TEST_ROOT/link-state" \
    "$link_repo/tooling/scripts/install.sh" --global "$@" > "$TEST_ROOT/link-log" 2>&1
}
link_remove() {
  DOTAGENTS_HOME="$TEST_ROOT/link-home" XDG_STATE_HOME="$TEST_ROOT/link-state" \
    "$link_repo/tooling/scripts/uninstall.sh" --global > "$TEST_ROOT/link-log" 2>&1
}
apply_root="$TEST_ROOT/explicit"
mkdir -p "$apply_root/source/dot_claude" "$apply_root/source/dot_codex" "$apply_root/destination/.claude" \
  "$apply_root/config" "$apply_root/state" "$apply_root/cache" "$apply_root/process-home"
cp "$link_repo/agents/adapters/claude/settings.json" "$apply_root/source/dot_claude/settings.json"
cp "$link_repo/agents/adapters/codex/hooks.json" "$apply_root/source/dot_codex/hooks.json"
printf '%s\n' '# isolated comparison' > "$apply_root/config/chezmoi.toml"
cm() {
  HOME="$apply_root/process-home" "$chezmoi_bin" \
    --source "$apply_root/source" --destination "$apply_root/destination" \
    --config "$apply_root/config/chezmoi.toml" --persistent-state "$apply_root/state/db" \
    --cache "$apply_root/cache" --working-tree "$apply_root/source" \
    --mode file --no-pager --no-tty --less-interactive --error-on-conflict "$@"
}
link_target="$TEST_ROOT/link-home/.claude/settings.json"
apply_target="$apply_root/destination/.claude/settings.json"

printf '%s\n' '{"fixture": "original-user-file"}' > "$link_target"
cp "$link_target" "$apply_target"
expect_failure link_install
expect_failure cm apply
grep -q original-user-file "$link_target" || fail 'link conflict changed user content'
grep -q original-user-file "$apply_target" || fail 'apply conflict changed user content'
[[ ! -e "$TEST_ROOT/link-home/.agents" ]] || fail 'link preflight made partial changes'
echo 'PASS initial conflict: both preserve the conflicting file (link preflight makes no links)'

# Forced mode is an explicit experiment, not the profile's apply policy.
link_install --force
cp "$apply_target" "$TEST_ROOT/manual-user-backup"
cm --force apply
link_install
cm apply
[[ -z "$(cm status)" ]] || fail 'repeat apply has drift'
echo 'PASS forced/repeated apply: link installer records backup; chezmoi requires our manual backup'

printf '%s\n' '{"fixture": "v2"}' > "$link_repo/agents/adapters/claude/settings.json"
cp "$link_repo/agents/adapters/claude/settings.json" "$apply_root/source/dot_claude/settings.json"
grep -q v2 "$link_target" || fail 'source edit was not live through the link'
grep -q v1 "$apply_target" || fail 'source edit unexpectedly became live in explicit mode'
[[ -n "$(cm status)" ]] || fail 'explicit source drift not detected'
cm apply
cmp -s "$link_target" "$apply_target" || fail 'explicit apply did not converge'
echo 'PASS source drift: link is immediate; explicit mode detects pending change then converges on apply'

# Writing through the link modifies the source; writing to the copied target does not.
printf '%s\n' '{"fixture": "target-user-edit"}' > "$link_target"
cp "$link_target" "$apply_target"
grep -q target-user-edit "$link_repo/agents/adapters/claude/settings.json" || fail 'link edit did not reach source'
grep -q v2 "$apply_root/source/dot_claude/settings.json" || fail 'explicit target edit reached source'
expect_failure cm apply
grep -q target-user-edit "$apply_target" || fail 'user edit was overwritten'
echo 'PASS target edits: link writes into checkout; explicit target edit stays local and apply fails on conflict'

# Repair explicit drift, then create a later conflict in the same two-file batch.
cm --force apply
printf '%s\n' '{"fixture": "v3"}' > "$link_repo/agents/adapters/claude/settings.json"
cp "$link_repo/agents/adapters/claude/settings.json" "$apply_root/source/dot_claude/settings.json"
printf '%s\n' '{"fixture": "user-hooks"}' > "$apply_root/destination/.codex/hooks.json"
expect_failure cm apply
grep -q v3 "$apply_target" || fail 'expected earlier file to be applied before later conflict'
grep -q user-hooks "$apply_root/destination/.codex/hooks.json" || fail 'later conflict lost user data'
echo 'PASS partial apply observation: earlier chezmoi file updated before later conflict; no batch rollback'

# The existing installer also has runtime rollback. Inject an ln error after its
# earlier writes, reusing the same payloads and a separate temporary home.
mkdir -p "$TEST_ROOT/failure-bin" "$TEST_ROOT/failure-home/.claude" "$TEST_ROOT/failure-home/.codex"
printf '%s\n' '{"fixture": "original-user-file"}' > "$TEST_ROOT/failure-home/.claude/settings.json"
printf '%s\n' '{"fixture": "user-hooks"}' > "$TEST_ROOT/failure-home/.codex/hooks.json"
real_ln="$(command -v ln)"
export ENVIRONMENT_COMPARE_REAL_LN="$real_ln" ENVIRONMENT_COMPARE_FAIL_TARGET="$TEST_ROOT/failure-home/.codex/hooks.json"
cat > "$TEST_ROOT/failure-bin/ln" <<'STUB'
#!/usr/bin/env bash
[[ "${@: -1}" != "$ENVIRONMENT_COMPARE_FAIL_TARGET" ]] || exit 1
exec "$ENVIRONMENT_COMPARE_REAL_LN" "$@"
STUB
chmod +x "$TEST_ROOT/failure-bin/ln"
expect_failure env PATH="$TEST_ROOT/failure-bin:$PATH" DOTAGENTS_HOME="$TEST_ROOT/failure-home" \
  XDG_STATE_HOME="$TEST_ROOT/failure-state" "$link_repo/tooling/scripts/install.sh" --global --force
grep -q original-user-file "$TEST_ROOT/failure-home/.claude/settings.json" || fail 'link rollback lost first original'
grep -q user-hooks "$TEST_ROOT/failure-home/.codex/hooks.json" || fail 'link rollback lost later original'
[[ ! -e "$TEST_ROOT/failure-home/.agents" ]] || fail 'link rollback left an earlier link'
[[ ! -e "$TEST_ROOT/failure-state/dotagents/install.tsv" ]] || fail 'failed link install published manifest'
echo 'PASS injected link runtime failure: originals restored and earlier links rolled back'

# Remove ownership from source vs remove from both states are different actions.
cm --force apply
cp "$apply_root/source/dot_claude/settings.json" "$TEST_ROOT/source-before-removal"
rm "$apply_root/source/dot_claude/settings.json"
cm apply
[[ -f "$apply_target" ]] || fail 'unmanaging a source unexpectedly deleted target'
cp "$TEST_ROOT/source-before-removal" "$apply_root/source/dot_claude/settings.json"
cm --force destroy "$apply_target"
[[ ! -e "$apply_target" && ! -e "$apply_root/source/dot_claude/settings.json" ]] || fail 'destroy did not remove both states'
expect_failure cm --force destroy "$apply_target"
link_remove
grep -q original-user-file "$link_target" || fail 'link uninstall did not restore backup'
link_remove
cm apply
[[ ! -e "$apply_target" ]] || fail 'repeat apply resurrected destroyed target'
echo 'PASS removal/repeat: link uninstall restores backup and repeats; source deletion leaves copied target; destroy deletes both, repeat destroy errors'

# A replacement, as opposed to writing through a link, no longer belongs to the installer.
link_install --force
unlink "$link_target"
printf '%s\n' '{"fixture": "replacement"}' > "$link_target"
link_remove
grep -q replacement "$link_target" || fail 'link uninstall removed user replacement'
echo 'PASS link replacement: uninstall preserves a user-owned replacement'
echo 'All bounded deployment comparisons passed; temporary fixtures removed on exit.'
