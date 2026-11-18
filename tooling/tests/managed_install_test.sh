#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-managed-test.XXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"
trap 'rm -r "$TEST_ROOT"' EXIT
fail() { echo "test failed: $*" >&2; exit 1; }
source_repo="$TEST_ROOT/source"
mkdir "$source_repo"
cp -R "$REPO_ROOT/agents" "$REPO_ROOT/dist" "$REPO_ROOT/tooling" "$source_repo/"
use_home() {
  home_dir="$TEST_ROOT/$1"
  state_dir="$TEST_ROOT/$1-state"
  manifest="$state_dir/dotagents/install.tsv"
  metadata="${manifest}.meta.tsv"
  mkdir -p "$home_dir" "$state_dir"
}
install_managed() { DOTAGENTS_HOME="$home_dir" XDG_STATE_HOME="$state_dir" "$source_repo/tooling/scripts/install.sh" --global --layout managed "$@" > "$TEST_ROOT/output" 2>&1; }
install_legacy() { DOTAGENTS_HOME="$home_dir" XDG_STATE_HOME="$state_dir" "$source_repo/tooling/scripts/install.sh" --global "$@" > "$TEST_ROOT/output" 2>&1; }
remove() { DOTAGENTS_HOME="$home_dir" XDG_STATE_HOME="$state_dir" "$source_repo/tooling/scripts/uninstall.sh" --global > "$TEST_ROOT/output" 2>&1; }
doctor() { DOTAGENTS_HOME="$home_dir" XDG_STATE_HOME="$state_dir" "$REPO_ROOT/tooling/scripts/doctor.sh" > "$TEST_ROOT/output" 2>&1; }
snapshot() {
  find "$@" -type d -print | LC_ALL=C sort
  find "$@" -type l -exec sh -c 'for p do printf "%s -> %s\n" "$p" "$(readlink "$p")"; done' sh {} + | LC_ALL=C sort
  find "$@" -type f -exec cksum {} + | LC_ALL=C sort
}

echo 'scenario: managed install preserves a real shared namespace and seeds only absent user settings'
use_home fresh
mkdir -p "$home_dir/.agents/skills/foreign" "$home_dir/.claude/skills/foreign"
printf '%s\n' 'foreign shared skill' > "$home_dir/.agents/skills/foreign/SKILL.md"
printf '%s\n' 'foreign Claude skill' > "$home_dir/.claude/skills/foreign/SKILL.md"
printf '%s\n' 'foreign root content' > "$home_dir/.agents/foreign-note"
snapshot "$source_repo/agents" > "$TEST_ROOT/source-before"
snapshot "$home_dir" "$state_dir" > "$TEST_ROOT/dry-before"
install_managed --dry-run
snapshot "$home_dir" "$state_dir" > "$TEST_ROOT/dry-after"
cmp -s "$TEST_ROOT/dry-before" "$TEST_ROOT/dry-after" || fail 'managed dry-run mutated targets or state'
install_managed
[[ -d "$home_dir/.agents" && ! -L "$home_dir/.agents" && ! -L "$home_dir/.agents/skills" ]] || fail 'managed shared directories are symbolic links'
for path in rules hooks templates; do
  [[ "$(readlink "$home_dir/.agents/$path")" == "$source_repo/agents/$path" ]] || fail "missing compatible shared $path path"
done
[[ "$(readlink "$home_dir/.agents/skills/fsd-refactor")" == "$source_repo/agents/skills/owned/fsd-refactor" ]] || fail 'shared owned skill points to wrong source'
for config in .claude/settings.json .codex/hooks.json; do
  [[ -f "$home_dir/$config" && ! -L "$home_dir/$config" ]] || fail 'settings seed is not a regular file'
  jq -e 'keys == ["hooks"]' "$home_dir/$config" >/dev/null || fail 'seed imported unrelated host policy'
  ! grep -Fq "$home_dir/$config" "$manifest" || fail 'user-owned seed became an owned ledger target'
done
[[ "$(head -n 1 "$manifest")" == '# dotagents-layout=managed-v1' ]] || fail 'managed ledger marker is absent'
grep -Fqx $'layout\tmanaged' "$metadata" || fail 'layout is not explicitly recorded'
doctor || fail 'doctor rejected fresh managed layout'
mkdir "$home_dir/.agents/skills/added-by-tool"
printf '%s\n' 'added after installation' > "$home_dir/.agents/skills/added-by-tool/SKILL.md"
[[ ! -e "$source_repo/agents/skills/added-by-tool" ]] || fail 'another tool wrote through the shared namespace into source'
# Every declared fixed/skill link is checked, independently of enumeration.
while IFS=$'\t' read -r target source _; do
  [[ "$target" != '# dotagents-layout=managed-v1' ]] || continue
  unlink "$target"
  ! doctor || fail "doctor ignored missing managed link: $target"
  grep -Fq "$target" "$TEST_ROOT/output" || fail "doctor did not name managed target: $target"
  ln -s "$source" "$target"
done < "$manifest"
doctor || fail 'doctor rejected restored managed links'
printf '%s\n' '{"userPreference":true,"hooks":{"PreToolUse":[]}}' > "$home_dir/.claude/settings.json"
cp "$home_dir/.claude/settings.json" "$TEST_ROOT/user-settings"
install_managed --force
cmp -s "$TEST_ROOT/user-settings" "$home_dir/.claude/settings.json" || fail 'repeat install overwrote settings'
! doctor || fail 'doctor ignored missing user hook registration'
grep -Fq 'manually integrate the PreToolUse hook' "$TEST_ROOT/output" || fail 'manual hook repair is not actionable'
snapshot "$source_repo/agents" > "$TEST_ROOT/source-after"
cmp -s "$TEST_ROOT/source-before" "$TEST_ROOT/source-after" || fail 'managed writes changed tracked source'
remove
[[ ! -e "$manifest" && ! -e "$metadata" ]] || fail 'managed remove retained a completed ledger'
cmp -s "$TEST_ROOT/user-settings" "$home_dir/.claude/settings.json" || fail 'remove changed user settings'
[[ -f "$home_dir/.codex/hooks.json" ]] || fail 'remove deleted an adopted seed'
grep -q 'foreign shared skill' "$home_dir/.agents/skills/foreign/SKILL.md" || fail 'remove deleted foreign shared skill'
grep -q 'foreign Claude skill' "$home_dir/.claude/skills/foreign/SKILL.md" || fail 'remove deleted foreign Claude skill'
grep -q 'foreign root content' "$home_dir/.agents/foreign-note" || fail 'remove deleted foreign shared content'
grep -q 'added after installation' "$home_dir/.agents/skills/added-by-tool/SKILL.md" || fail 'remove deleted a skill added by another tool'
doctor || fail 'leftover user-owned directories imply an installation'
grep -q '^skip: host entry points' "$TEST_ROOT/output" || fail 'doctor inferred ownership from a shared directory'

echo 'scenario: added and retired skills manage only their individual shared and Claude links'
use_home dynamic
mkdir -p "$source_repo/agents/skills/owned/fixture-managed" "$home_dir/.agents/skills/fixture-managed" "$home_dir/.claude/skills"
printf '%s\n' '---' 'name: fixture-managed' 'description: Managed fixture skill.' '---' > "$source_repo/agents/skills/owned/fixture-managed/SKILL.md"
cp "$source_repo/agents/registry/skills.toml" "$TEST_ROOT/dynamic-registry"
cat >> "$source_repo/agents/registry/skills.toml" <<'REGISTRY'

[[skills]]
id = "fixture-managed"
kind = "owned"
source = "agents/skills/owned/fixture-managed"
license = "MIT"
hosts = ["claude", "codex", "gemini"]
profiles = ["default", "full"]
workflows = []
optional = true
enabled_by_default = true
REGISTRY
ln -s owned/fixture-managed "$source_repo/agents/skills/fixture-managed"
printf '%s\n' 'original shared fixture' > "$home_dir/.agents/skills/fixture-managed/note"
printf '%s\n' 'original Claude fixture' > "$home_dir/.claude/skills/fixture-managed"
install_managed --force
for target in "$home_dir/.agents/skills/fixture-managed" "$home_dir/.claude/skills/fixture-managed"; do
  [[ "$(readlink "$target")" == "$source_repo/agents/skills/owned/fixture-managed" ]] || fail 'new managed skill source is wrong'
done
doctor || fail 'doctor rejected dynamically added managed skill'
unlink "$home_dir/.agents/skills/fixture-managed"
! doctor || fail 'doctor ignored new shared skill missing link'
grep -Fq 'missing: shared skill link (fixture-managed)' "$TEST_ROOT/output" || fail 'doctor did not identify new shared skill'
ln -s "$source_repo/agents/skills/owned/fixture-managed" "$home_dir/.agents/skills/fixture-managed"
rm -r "$source_repo/agents/skills/owned/fixture-managed"
unlink "$source_repo/agents/skills/fixture-managed"
mv "$TEST_ROOT/dynamic-registry" "$source_repo/agents/registry/skills.toml"
install_managed
grep -q 'original shared fixture' "$home_dir/.agents/skills/fixture-managed/note" || fail 'retired shared skill backup was lost'
grep -q 'original Claude fixture' "$home_dir/.claude/skills/fixture-managed" || fail 'retired Claude skill backup was lost'
! grep -q fixture-managed "$manifest" || fail 'retired managed skill stayed in ledger'
remove

echo 'scenario: existing settings, owned-name conflicts, and user replacements survive removal'
use_home conflicts
mkdir -p "$home_dir/.agents/skills/fsd-refactor" "$home_dir/.agents/rules" "$home_dir/.claude" "$home_dir/.codex"
printf '%s\n' 'foreign name collision' > "$home_dir/.agents/skills/fsd-refactor/note"
printf '%s\n' 'foreign rules' > "$home_dir/.agents/rules/note"
printf '%s\n' '{"userClaude":true}' > "$home_dir/.claude/settings.json"
printf '%s\n' '{"userCodex":true}' > "$home_dir/.codex/hooks.json"
snapshot "$home_dir" "$state_dir" > "$TEST_ROOT/before"
! install_managed || fail 'managed conflict was replaced without force'
snapshot "$home_dir" "$state_dir" > "$TEST_ROOT/after"
cmp -s "$TEST_ROOT/before" "$TEST_ROOT/after" || fail 'conflict refusal mutated files'
install_managed --force
jq -e '.userClaude == true' "$home_dir/.claude/settings.json" >/dev/null || fail '--force replaced user Claude config'
jq -e '.userCodex == true' "$home_dir/.codex/hooks.json" >/dev/null || fail '--force replaced user Codex config'
! doctor || fail 'missing user hook registrations passed'
[[ "$(grep -c '^missing: .*required commit hook registration' "$TEST_ROOT/output")" -eq 2 ]] || fail 'both required hook diagnostics are not present'
unlink "$home_dir/.agents/skills/usage-guide"
printf '%s\n' 'user replacement' > "$home_dir/.agents/skills/usage-guide"
remove
[[ "$(cat "$home_dir/.agents/skills/usage-guide")" == 'user replacement' ]] || fail 'remove deleted user replacement'
grep -q 'foreign name collision' "$home_dir/.agents/skills/fsd-refactor/note" || fail 'remove lost owned-name backup'
grep -q 'foreign rules' "$home_dir/.agents/rules/note" || fail 'remove lost fixed-entry backup'
[[ -f "$metadata" ]] || fail 'partial removal lost its managed layout metadata'
cp "$metadata" "$TEST_ROOT/partial-metadata"
rm "$metadata"
! doctor || fail 'partial managed ledger without metadata passed'
! remove || fail 'partial managed ledger lost its layout guard'
mv "$TEST_ROOT/partial-metadata" "$metadata"

echo 'scenario: unrecorded exact, alternate, and dangling links into the checkout are user-owned'
use_home unrecorded-links
mkdir -p "$home_dir/.agents/skills" "$home_dir/.claude/skills" "$home_dir/.gemini"
shared_skill="$home_dir/.agents/skills/fsd-refactor"
claude_skill="$home_dir/.claude/skills/fsd-refactor"
gemini_rules="$home_dir/.gemini/GEMINI.md"
expected_skill="$source_repo/agents/skills/owned/fsd-refactor"
alternate_skill="$source_repo/agents/skills/owned/usage-guide"
missing_rules="$source_repo/missing-rules"
ln -s "$alternate_skill" "$shared_skill"
ln -s "$expected_skill" "$claude_skill"
ln -s "$missing_rules" "$gemini_rules"
snapshot "$home_dir" "$state_dir" > "$TEST_ROOT/before"
install_managed --dry-run
grep -Fq '3 conflict(s) found' "$TEST_ROOT/output" || fail 'preview missed an unrecorded symlink conflict'
! install_managed || fail 'unrecorded links were adopted without force'
snapshot "$home_dir" "$state_dir" > "$TEST_ROOT/after"
cmp -s "$TEST_ROOT/before" "$TEST_ROOT/after" || fail 'conflict handling changed unrecorded links'
install_managed --force
[[ "$(readlink "$shared_skill")" == "$expected_skill" ]] || fail 'force did not install the owned shared skill'
[[ "$(readlink "$gemini_rules")" == "$source_repo/dist/gemini/GEMINI.md" ]] || fail 'force did not install the host rules'
for target in "$shared_skill" "$claude_skill" "$gemini_rules"; do
  backup="$(awk -F '\t' -v target="$target" '$1 == target { print $3 }' "$manifest")"
  [[ -L "$backup" ]] || fail "force did not record an original link backup: $target"
done
install_managed
remove
[[ "$(readlink "$shared_skill")" == "$alternate_skill" ]] || fail 'uninstall lost original alternate-source link'
[[ "$(readlink "$claude_skill")" == "$expected_skill" ]] || fail 'uninstall lost original exact-source link'
[[ "$(readlink "$gemini_rules")" == "$missing_rules" ]] || fail 'uninstall lost original dangling link'

echo 'scenario: host-only partial ledgers still require managed metadata'
use_home partial-host
install_managed
unlink "$home_dir/.claude/CLAUDE.md"
printf '%s\n' 'user host rules' > "$home_dir/.claude/CLAUDE.md"
remove
[[ "$(wc -l < "$manifest" | tr -d ' ')" -eq 2 ]] || fail 'expected only marker and modified host row after partial removal'
rm "$metadata"
! doctor || fail 'host-only managed ledger without metadata passed'
! remove || fail 'host-only managed ledger lost its layout guard'

echo 'scenario: legacy migration is explicit and cannot write through .agents even with force'
use_home legacy
install_legacy
doctor || fail 'legacy default compatibility failed'
snapshot "$source_repo/agents" "$home_dir" "$state_dir" > "$TEST_ROOT/before"
! install_managed --force || fail 'managed install traversed a legacy .agents link'
snapshot "$source_repo/agents" "$home_dir" "$state_dir" > "$TEST_ROOT/after"
cmp -s "$TEST_ROOT/before" "$TEST_ROOT/after" || fail 'legacy refusal wrote through source or changed the install'
remove
install_managed
doctor || fail 'explicit uninstall/reinstall migration failed'
! install_legacy --force || fail 'legacy install converted managed layout implicitly'
remove
# Even a foreign directory with a source-looking rule is not managed ownership.
mkdir -p "$home_dir/.agents/rules"
printf '%s\n' 'unrelated rule' > "$home_dir/.agents/rules/git.md"
doctor || fail 'foreign shared directory was treated as managed installation'
grep -q '^skip: host entry points' "$TEST_ROOT/output" || fail 'foreign source-looking directory was inferred as installed'

echo 'scenario: symlinked shared parents and settings are fail-closed'
for parent in .agents .agents/skills .claude; do
  use_home "unsafe-${parent//\//-}"
  mkdir -p "$(dirname "$home_dir/$parent")"
  ln -s "$source_repo/agents" "$home_dir/$parent"
  snapshot "$home_dir" "$state_dir" "$source_repo/agents" > "$TEST_ROOT/before"
  ! install_managed --force || fail "managed install accepted symlinked $parent"
  snapshot "$home_dir" "$state_dir" "$source_repo/agents" > "$TEST_ROOT/after"
  cmp -s "$TEST_ROOT/before" "$TEST_ROOT/after" || fail "managed refusal mutated $parent source"
done
mkdir "$TEST_ROOT/project"
! "$source_repo/tooling/scripts/install.sh" --project "$TEST_ROOT/project" --layout managed > "$TEST_ROOT/output" 2>&1 || fail 'project install accepted unsupported managed layout'
[[ -z "$(find "$TEST_ROOT/project" -mindepth 1 -print)" ]] || fail 'managed project refusal mutated project'
use_home unsafe-settings
mkdir "$home_dir/.claude"
ln -s "$source_repo/agents/adapters/claude/settings.json" "$home_dir/.claude/settings.json"
! install_managed --force || fail 'managed mode adopted a tracked settings link'
[[ ! -e "$home_dir/.agents" ]] || fail 'settings symlink refusal partially installed'

use_home metadata
install_managed
cp "$metadata" "$TEST_ROOT/good-metadata"
cp "$manifest" "$TEST_ROOT/good-manifest"
echo 'scenario: missing, malformed, duplicate, or mismatched metadata never triggers mutation'
for damage in missing version duplicate unknown root source header orphan; do
  cp "$TEST_ROOT/good-metadata" "$metadata"
  cp "$TEST_ROOT/good-manifest" "$manifest"
  case "$damage" in
    missing) rm "$metadata" ;;
    version) sed $'s/version\t1/version\t2/' "$TEST_ROOT/good-metadata" > "$metadata" ;;
    duplicate) printf 'layout\tmanaged\n' >> "$metadata" ;;
    unknown) printf 'unknown\tvalue\n' >> "$metadata" ;;
    root) sed $'s/target_root\t.*/target_root\t\/wrong-home/' "$TEST_ROOT/good-metadata" > "$metadata" ;;
    source) sed $'s/agents\t.*/agents\trelative-source/' "$TEST_ROOT/good-metadata" > "$metadata" ;;
    header) tail -n +2 "$TEST_ROOT/good-manifest" > "$manifest" ;;
    orphan) rm "$manifest" ;;
  esac
  snapshot "$home_dir" "$state_dir" > "$TEST_ROOT/before"
  ! doctor || fail "$damage metadata was accepted by doctor"
  ! install_managed --force || fail "$damage metadata was accepted by install"
  ! remove || fail "$damage metadata was accepted by remove"
  snapshot "$home_dir" "$state_dir" > "$TEST_ROOT/after"
  cmp -s "$TEST_ROOT/before" "$TEST_ROOT/after" || fail "$damage metadata caused mutations"
done
cp "$TEST_ROOT/good-metadata" "$metadata"
cp "$TEST_ROOT/good-manifest" "$manifest"
# Uninstall must also refuse a replaced shared parent instead of unlinking source.
mv "$home_dir/.agents" "$home_dir/saved-agents"
ln -s "$source_repo/agents" "$home_dir/.agents"
snapshot "$source_repo/agents" > "$TEST_ROOT/before"
! remove || fail 'uninstall traversed a replaced shared root'
snapshot "$source_repo/agents" > "$TEST_ROOT/after"
cmp -s "$TEST_ROOT/before" "$TEST_ROOT/after" || fail 'uninstall changed source through a replaced root'
unlink "$home_dir/.agents"
mv "$home_dir/saved-agents" "$home_dir/.agents"

echo 'scenario: source relocation updates recorded layout/source without overwriting adopted configs'
moved_repo="$TEST_ROOT/moved"
cp -R "$source_repo" "$moved_repo"
old_repo="$source_repo"
source_repo="$moved_repo"
cp "$home_dir/.claude/settings.json" "$TEST_ROOT/adopted-settings"
install_managed
[[ "$(readlink "$home_dir/.agents/rules")" == "$moved_repo/agents/rules" ]] || fail 'managed update did not relocate fixed links'
grep -Fqx "$(printf 'agents\t%s' "$moved_repo/agents")" "$metadata" || fail 'recorded source did not relocate'
cmp -s "$TEST_ROOT/adopted-settings" "$home_dir/.claude/settings.json" || fail 'managed update replaced adopted config'
doctor || fail 'doctor used caller instead of recorded relocated source'
remove
source_repo="$old_repo"

echo 'scenario: the installed promotion skill resolves the primary checkout in both layouts'
source_repo="$TEST_ROOT/promotion-source"
mkdir "$source_repo"
cp -R "$REPO_ROOT/agents" "$REPO_ROOT/dist" "$REPO_ROOT/tooling" "$REPO_ROOT/dotagents.toml" "$source_repo/"
git -C "$source_repo" init -q --initial-branch=main
promote_resolver='scripts/resolve-source.sh'
resolve_promote() {
  DOTAGENTS_HOME="$home_dir" XDG_STATE_HOME="$state_dir" "$1/$promote_resolver" 2> "$TEST_ROOT/output"
}
use_home promote-managed
install_managed
managed_skill="$home_dir/.agents/skills/dotagents-promote"
[[ "$(resolve_promote "$managed_skill")" == "$source_repo" ]] || fail 'managed promotion did not resolve the installed checkout'
[[ "$(resolve_promote "$home_dir/.claude/skills/dotagents-promote")" == "$source_repo" ]] || fail 'Claude promotion did not resolve the managed checkout'
cp "$metadata" "$TEST_ROOT/promotion-metadata"
while IFS=$'\t' read -r key value; do
  [[ "$key" != agents ]] || value="$moved_repo/agents"
  printf '%s\t%s\n' "$key" "$value"
done < "$TEST_ROOT/promotion-metadata" > "$metadata"
! resolve_promote "$managed_skill" || fail 'managed promotion accepted a mismatched recorded source'
mv "$TEST_ROOT/promotion-metadata" "$metadata"
unlink "$home_dir/.agents/rules"
ln -s "$moved_repo/agents/rules" "$home_dir/.agents/rules"
! resolve_promote "$managed_skill" || fail 'managed promotion accepted a mismatched live rules link'
unlink "$home_dir/.agents/rules"
ln -s "$source_repo/agents/rules" "$home_dir/.agents/rules"
rm "$metadata"
! resolve_promote "$managed_skill" || fail 'managed promotion accepted an incomplete installation record'
use_home promote-legacy
install_legacy
rm "$manifest"
legacy_skill="$home_dir/.agents/skills/dotagents-promote"
[[ "$(resolve_promote "$legacy_skill")" == "$source_repo" ]] || fail 'promotion did not resolve a legacy install without a ledger'
git -C "$source_repo" symbolic-ref HEAD refs/heads/not-main
! resolve_promote "$legacy_skill" || fail 'promotion accepted a primary checkout off main'
git -C "$source_repo" symbolic-ref HEAD refs/heads/main
use_home promote-foreign
mkdir "$home_dir/.agents"
ln -s "$source_repo/agents/rules" "$home_dir/.agents/rules"
! resolve_promote "$source_repo/agents/skills/owned/dotagents-promote" || fail 'promotion inferred ownership from an unrecorded shared directory'
source_repo="$old_repo"

failure_bin="$TEST_ROOT/failure-bin"
mkdir "$failure_bin"
export MANAGED_TEST_LN="$(command -v ln)" MANAGED_TEST_MV="$(command -v mv)"
for operation in ln mv; do
  cat > "$failure_bin/$operation" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
operation="${0##*/}"
real="$MANAGED_TEST_MV"
[[ "$operation" != ln ]] || real="$MANAGED_TEST_LN"
target="${@: -1}"
if [[ "$operation" == ln && "$1" != -s ]]; then
  target="${target%/}/${1##*/}"
fi
if [[ "$target" == "${HOST_CREATE_TARGET:-}" ]]; then
  case "$HOST_CREATE_KIND" in
    file) printf '%s\n' '{"createdByHost":true}' > "$target" ;;
    directory) mkdir "$target" ;;
    symlink) "$MANAGED_TEST_LN" -s "$HOST_OUTSIDE" "$target" ;;
  esac
fi
if [[ "$operation" == "${FAIL_OPERATION:-}" && "$target" == "$FAIL_TARGET" && "$1" != */previous-* ]]; then
  case "${HOST_CHANGE_SEED:-}" in
    replace) cp "$HOST_SETTINGS" "$HOST_SETTINGS.replacement"; "$MANAGED_TEST_MV" "$HOST_SETTINGS.replacement" "$HOST_SETTINGS" ;;
    edit) printf '%s\n' '{"editedByHost":true}' > "$HOST_SETTINGS" ;;
  esac
  if [[ "$FAIL_SIGNAL" != error ]]; then
    "$real" "$@"
    kill -s "$FAIL_SIGNAL" "$PPID"
    exit 0
  fi
  exit 73
fi
exec "$real" "$@"
WRAPPER
  chmod +x "$failure_bin/$operation"
done

echo 'scenario: a host can publish its own settings at the same instant as the seed'
for kind in file directory symlink; do
  use_home "late-settings-$kind"
  target="$home_dir/.claude/settings.json"
  outside="$home_dir/other-settings"
  mkdir "$outside"
  printf '%s\n' 'unrelated content' > "$outside/note"
  if PATH="$failure_bin:$PATH" HOST_CREATE_TARGET="$target" HOST_CREATE_KIND="$kind" HOST_OUTSIDE="$outside" install_managed; then
    [[ "$kind" == file ]] || fail "installer accepted a concurrent settings $kind"
    jq -e '.createdByHost == true' "$target" >/dev/null || fail 'seed overwrote settings created concurrently by the host'
    [[ -f "$manifest" && -f "$metadata" ]] || fail 'concurrent regular settings prevented install'
  else
    [[ "$kind" != file ]] || fail 'concurrent regular settings prevented install'
    [[ ! -e "$manifest" && ! -e "$metadata" ]] || fail 'settings conflict committed partial state'
    [[ ! -e "$home_dir/.codex/hooks.json" && ! -L "$home_dir/.claude/CLAUDE.md" ]] || fail 'settings conflict left installed targets'
    case "$kind" in
      directory) [[ -d "$target" && -z "$(ls -A "$target")" ]] || fail 'seed wrote into the concurrent settings directory' ;;
      symlink) [[ "$(readlink "$target")" == "$outside" ]] || fail 'seed replaced the concurrent settings symlink' ;;
    esac
  fi
  [[ "$(ls -A "$outside")" == note ]] || fail 'seed followed a concurrent settings symlink'
  [[ -z "$(find "$home_dir" -name '.dotagents-seed.*')" ]] || fail 'seed staging directory survived publication'
done

echo 'scenario: rollback preserves host edits and same-byte replacement inodes'
for change in replace edit; do
  use_home "rollback-user-settings-$change"
  target="$home_dir/.claude/settings.json"
  if PATH="$failure_bin:$PATH" FAIL_OPERATION=mv FAIL_TARGET="$metadata" FAIL_SIGNAL=TERM HOST_CHANGE_SEED="$change" HOST_SETTINGS="$target" install_managed; then
    fail 'metadata interruption did not fail installation'
  fi
  [[ ! -e "$manifest" && ! -e "$metadata" ]] || fail 'metadata interruption committed partial state'
  [[ ! -e "$home_dir/.codex/hooks.json" ]] || fail 'unchanged Codex seed survived rollback'
  case "$change" in
    replace) cmp -s "$source_repo/agents/adapters/claude/hooks.example.json" "$target" || fail 'rollback removed the host replacement with the same bytes' ;;
    edit) jq -e '.editedByHost == true' "$target" >/dev/null || fail 'rollback removed the host edit' ;;
  esac
done

echo 'scenario: failure, INT, and TERM recover links, settings seeds, manifest, and metadata'
for signal in error INT TERM; do
  for stage in link seed ledger metadata; do
    use_home "rollback-$stage-$signal"
    mkdir -p "$home_dir/.claude" "$home_dir/.agents/skills/foreign"
    printf '%s\n' 'original host rules' > "$home_dir/.claude/CLAUDE.md"
    case "$stage" in
      link) operation=ln; target="$home_dir/.agents/skills/fsd-refactor" ;;
      seed) operation=ln; target="$home_dir/.codex/hooks.json" ;;
      ledger) operation=mv; target="$manifest" ;;
      metadata) operation=mv; target="$metadata" ;;
    esac
    if PATH="$failure_bin:$PATH" FAIL_OPERATION="$operation" FAIL_TARGET="$target" FAIL_SIGNAL="$signal" install_managed --force; then
      fail "$stage $signal injection did not fail"
    fi
    [[ ! -L "$home_dir/.claude/CLAUDE.md" && "$(cat "$home_dir/.claude/CLAUDE.md")" == 'original host rules' ]] || fail "$stage $signal lost original host file"
    [[ ! -e "$manifest" && ! -e "$metadata" ]] || fail "$stage $signal committed partial state"
    [[ ! -e "$home_dir/.claude/settings.json" && ! -e "$home_dir/.codex/hooks.json" ]] || fail "$stage $signal left uncommitted seeds"
    [[ -d "$home_dir/.agents/skills/foreign" ]] || fail "$stage $signal lost foreign content"
    [[ -z "$(find "$home_dir" -type l -print)" ]] || fail "$stage $signal left installed links"
    [[ -z "$(find "$home_dir" "$state_dir" -name '*.dotagents-backup.*' -o -name '*.transaction.*' -o -name '.dotagents-seed.*')" ]] || fail "$stage $signal left recovery files after successful rollback"
  done
done

echo 'scenario: a failed upgrade restores the previous ledger and metadata together'
use_home failed-upgrade
install_managed
cp "$manifest" "$TEST_ROOT/upgrade-manifest"
cp "$metadata" "$TEST_ROOT/upgrade-metadata"
source_repo="$moved_repo"
if PATH="$failure_bin:$PATH" FAIL_OPERATION=mv FAIL_TARGET="$metadata" FAIL_SIGNAL=TERM install_managed; then
  fail 'metadata commit interruption did not fail the upgrade'
fi
cmp -s "$manifest" "$TEST_ROOT/upgrade-manifest" || fail 'failed upgrade changed ledger'
cmp -s "$metadata" "$TEST_ROOT/upgrade-metadata" || fail 'failed upgrade changed layout/source metadata'
while IFS=$'\t' read -r target source _; do
  [[ "$target" != '# dotagents-layout=managed-v1' ]] || continue
  [[ "$(readlink "$target")" == "$source" ]] || fail 'failed upgrade did not restore recorded link'
done < "$manifest"
doctor || fail 'doctor rejected recovered managed upgrade'
! compgen -G "${manifest}.transaction.*" >/dev/null || fail 'failed upgrade left recovery files after successful rollback'
echo 'All managed install scenarios passed.'
