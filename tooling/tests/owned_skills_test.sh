#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-owned-test.XXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"
trap 'rm -r "$TEST_ROOT"' EXIT
fail() { echo "test failed: $*" >&2; exit 1; }

source_repo="$TEST_ROOT/source"
mkdir -p "$source_repo"
cp -R "$REPO_ROOT/agents" "$REPO_ROOT/dist" "$REPO_ROOT/tooling" "$source_repo/"
home_dir="$TEST_ROOT/home"
state_dir="$TEST_ROOT/state"
project_dir="$TEST_ROOT/project"
mkdir -p "$home_dir/.claude/skills" "$project_dir/.claude/skills"
install_global() {
  DOTAGENTS_HOME="$home_dir" XDG_STATE_HOME="$state_dir" "$source_repo/tooling/scripts/install.sh" --global "$@" > "$TEST_ROOT/output" 2>&1
}
install_project() {
  "$source_repo/tooling/scripts/install.sh" --project "$project_dir" "$@" > "$TEST_ROOT/output" 2>&1
}
run_doctor() {
  DOTAGENTS_HOME="$home_dir" XDG_STATE_HOME="$state_dir" "$REPO_ROOT/tooling/scripts/doctor.sh" > "$TEST_ROOT/output" 2>&1
}
add_skill() {
  local name="$1"
  mkdir -p "$source_repo/agents/skills/owned/$name"
  printf '%s\n' '---' "name: $name" 'description: Fixture skill.' '---' > "$source_repo/agents/skills/owned/$name/SKILL.md"
  ln -s "owned/$name" "$source_repo/agents/skills/$name"
  cat >> "$source_repo/agents/registry/skills.toml" <<REGISTRY

[[skills]]
id = "$name"
kind = "owned"
source = "agents/skills/owned/$name"
license = "MIT"
hosts = ["claude", "codex", "gemini"]
profiles = []
workflows = []
optional = true
enabled_by_default = false
REGISTRY
}
remove_registry_entry() {
  local name="$1"
  awk -v name="$name" 'BEGIN { RS="\\[\\[skills\\]\\]"; ORS="" } NR==1 { print; next } $0 !~ "(^|\n)id = \"" name "\"(\n|$)" { print "[[skills]]" $0 }' "$source_repo/agents/registry/skills.toml" > "$TEST_ROOT/registry"
  mv "$TEST_ROOT/registry" "$source_repo/agents/registry/skills.toml"
}
remove_skill() {
  local name="$1"
  rm -r "$source_repo/agents/skills/owned/$name"
  unlink "$source_repo/agents/skills/$name"
  remove_registry_entry "$name"
}

echo 'scenario: a new owned directory installs globally and in projects without name-list changes'
add_skill fixture-added
# A metadata opt-out is intentionally not an installation policy.
printf '%s\n' 'original global fixture' > "$home_dir/.claude/skills/fixture-added"
printf '%s\n' 'original project fixture' > "$project_dir/.claude/skills/fixture-added"
install_global --force
install_project --force
for target in "$home_dir/.claude/skills/fixture-added" "$project_dir/.claude/skills/fixture-added"; do
  [[ -L "$target" && "$(readlink "$target")" == "$source_repo/agents/skills/owned/fixture-added" ]] || fail "new owned skill was not installed: $target"
done
run_doctor || fail 'doctor rejected the new skill installed from another checkout'
grep -Fq 'ok: Claude skill link (fixture-added)' "$TEST_ROOT/output" || fail 'doctor ignored installed checkout skill'

# The caller has five owned skills, the installed checkout has six. The ledger
# is not the desired set, and old installations without a ledger still work.
echo 'scenario: declared but uninstalled skills and missing installed links are diagnosed without a ledger'
add_skill fixture-uninstalled
cp "$state_dir/dotagents/install.tsv" "$TEST_ROOT/manifest"
rm "$state_dir/dotagents/install.tsv"
! run_doctor || fail 'doctor ignored declared but uninstalled skill'
grep -Fq 'missing: Claude skill link (fixture-uninstalled)' "$TEST_ROOT/output" || fail 'doctor used caller or manifest skill set'
[[ ! -e "$home_dir/.claude/skills/fixture-uninstalled" ]] || fail 'doctor installed a declared skill'
remove_skill fixture-uninstalled
run_doctor || fail 'doctor requires a manifest for an existing install'
unlink "$home_dir/.claude/skills/fixture-added"
! run_doctor || fail 'doctor ignored missing installed fixture link'
grep -Fq 'missing: Claude skill link (fixture-added)' "$TEST_ROOT/output" || fail 'doctor did not name the missing fixture link'
ln -s "$source_repo/agents/skills/owned/fixture-added" "$home_dir/.claude/skills/fixture-added"
mv "$TEST_ROOT/manifest" "$state_dir/dotagents/install.tsv"

echo 'scenario: removing a skill retires owned links and restores recorded backups'
remove_skill fixture-added
install_global
install_project
[[ "$(cat "$home_dir/.claude/skills/fixture-added")" == 'original global fixture' ]] || fail 'global retirement did not restore the fixture backup'
[[ "$(cat "$project_dir/.claude/skills/fixture-added")" == 'original project fixture' ]] || fail 'project retirement did not restore the fixture backup'
! grep -q 'fixture-added' "$state_dir/dotagents/install.tsv" || fail 'retired skill remains in global ledger'
! grep -q 'fixture-added' "$project_dir/.dotagents-install.tsv" || fail 'retired skill remains in project ledger'

add_skill fixture-replaced
install_global
install_project
for target in "$home_dir/.claude/skills/fixture-replaced" "$project_dir/.claude/skills/fixture-replaced"; do
  unlink "$target"
  printf '%s\n' 'user replacement' > "$target"
done
remove_skill fixture-replaced
install_global
install_project
for target in "$home_dir/.claude/skills/fixture-replaced" "$project_dir/.claude/skills/fixture-replaced"; do
  [[ "$(cat "$target")" == 'user replacement' ]] || fail 'retirement changed user replacement'
done

echo 'scenario: invalid source sets fail before mutation in either install mode'
# Existing targets, manifests and a real backup must all survive --force.
for target in "$home_dir/.claude/CLAUDE.md" "$project_dir/AGENTS.md"; do
  unlink "$target"
  printf '%s\n' 'preserved backup content' > "$target"
done
install_global --force
install_project --force
snapshot() {
  # Include link destinations, regular content (manifest and backups), and all
  # directories so even a leftover transaction or new parent is observable.
  find "$home_dir" "$state_dir" "$project_dir" -type d -print | LC_ALL=C sort
  find "$home_dir" "$state_dir" "$project_dir" -type l -exec sh -c 'for p do printf "%s -> %s\n" "$p" "$(readlink "$p")"; done' sh {} + | LC_ALL=C sort
  find "$home_dir" "$state_dir" "$project_dir" -type f -exec cksum {} + | LC_ALL=C sort
}
cp -R "$source_repo/agents/skills/owned" "$TEST_ROOT/intact-owned"
for damage in missing empty invalid delimiter unicode partial symlink; do
  rm -r "$source_repo/agents/skills/owned"
  case "$damage" in
    missing) ;;
    empty) mkdir "$source_repo/agents/skills/owned" ;;
    *)
      cp -R "$TEST_ROOT/intact-owned" "$source_repo/agents/skills/owned"
      case "$damage" in
        invalid) mkdir "$source_repo/agents/skills/owned/Bad_Name" ;;
        delimiter) mkdir "$source_repo/agents/skills/owned/bad|name" ;;
        unicode) mkdir "$source_repo/agents/skills/owned/café" ;;
        partial) rm "$source_repo/agents/skills/owned/fsd-refactor/SKILL.md" ;;
        symlink) ln -s fsd-refactor "$source_repo/agents/skills/owned/fixture-symlink" ;;
      esac
      ;;
  esac
  snapshot > "$TEST_ROOT/before"
  ! run_doctor || fail "$damage installed source was accepted by doctor"
  grep -Fq 'invalid: installed owned skill source' "$TEST_ROOT/output" || fail "$damage installed source was not diagnosed"
  ! install_global --force || fail "$damage global source was accepted"
  ! install_project --force || fail "$damage project source was accepted"
  snapshot > "$TEST_ROOT/after"
  cmp -s "$TEST_ROOT/before" "$TEST_ROOT/after" || fail "$damage source mutated targets, manifest or backups"
  [[ ! -e "$source_repo/agents/skills/owned" ]] || rm -r "$source_repo/agents/skills/owned"
  cp -R "$TEST_ROOT/intact-owned" "$source_repo/agents/skills/owned"
done

echo 'scenario: alias and registry checks cover every owned skill generically'
add_skill fixture-metadata
checker="$source_repo/tooling/scripts/check-owned-skills.sh"
"$checker" "$source_repo/agents" > "$TEST_ROOT/output" 2>&1 || fail 'valid new skill metadata failed'
cp "$source_repo/agents/registry/skills.toml" "$TEST_ROOT/valid-registry"
unlink "$source_repo/agents/skills/fixture-metadata"
! "$checker" "$source_repo/agents" > "$TEST_ROOT/output" 2>&1 || fail 'missing new skill alias passed'
ln -s owned/fsd-refactor "$source_repo/agents/skills/fixture-metadata"
! "$checker" "$source_repo/agents" > "$TEST_ROOT/output" 2>&1 || fail 'wrong new skill alias source passed'
unlink "$source_repo/agents/skills/fixture-metadata"
ln -s owned/fixture-metadata "$source_repo/agents/skills/fixture-metadata"
ln -s owned/fixture-metadata "$source_repo/agents/skills/fixture-duplicate"
! "$checker" "$source_repo/agents" > "$TEST_ROOT/output" 2>&1 || fail 'duplicate owned alias passed'
unlink "$source_repo/agents/skills/fixture-duplicate"
ln -s "$source_repo/agents/skills/owned/fixture-metadata" "$source_repo/agents/skills/fixture-duplicate"
! "$checker" "$source_repo/agents" > "$TEST_ROOT/output" 2>&1 || fail 'absolute duplicate owned alias passed'
unlink "$source_repo/agents/skills/fixture-duplicate"
for damage in missing duplicate wrong-source malformed; do
  cp "$TEST_ROOT/valid-registry" "$source_repo/agents/registry/skills.toml"
  case "$damage" in
    missing) remove_registry_entry fixture-metadata ;;
    duplicate) printf '\n[[skills]]\nid = "fixture-metadata"\nkind = "owned"\nsource = "agents/skills/owned/fixture-metadata"\n' >> "$source_repo/agents/registry/skills.toml" ;;
    wrong-source) sed 's|source = "agents/skills/owned/fixture-metadata"|source = "agents/skills/owned/fsd-refactor"|' "$TEST_ROOT/valid-registry" > "$source_repo/agents/registry/skills.toml" ;;
    malformed) sed 's|id = "fixture-metadata"|id = fixture-metadata|' "$TEST_ROOT/valid-registry" > "$source_repo/agents/registry/skills.toml" ;;
  esac
  ! "$checker" "$source_repo/agents" > "$TEST_ROOT/output" 2>&1 || fail "$damage registry passed"
done
cp "$TEST_ROOT/valid-registry" "$source_repo/agents/registry/skills.toml"
remove_skill fixture-metadata
"$checker" "$source_repo/agents" > "$TEST_ROOT/output" 2>&1 || fail 'valid removed skill metadata failed'
echo 'All owned skill scenarios passed.'
