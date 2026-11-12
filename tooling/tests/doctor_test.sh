#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-doctor-test.XXXXXX")"
trap 'rm -r "$TEST_ROOT"' EXIT

fail() { echo "test failed: $*" >&2; exit 1; }

run_doctor() {
  local expected="$1" actual=0
  DOTAGENTS_HOME="$test_home" XDG_STATE_HOME="$TEST_ROOT/state" "$REPO_ROOT/tooling/scripts/doctor.sh" > "$TEST_ROOT/output" 2>&1 || actual=$?
  [[ "$actual" -eq "$expected" ]] || fail "doctor returned $actual, expected $expected"
}

source_repo="$TEST_ROOT/source"
mkdir -p "$source_repo"
source_repo="$(cd "$source_repo" && pwd -P)"
cp -R "$REPO_ROOT/agents" "$REPO_ROOT/dist" "$source_repo/"

test_home="$TEST_ROOT/home"
mkdir -p "$test_home/.codex"

echo "scenario 1: an uninstalled checkout needs no global hooks"
run_doctor 0
grep -q '^skip: Codex commit hook link' "$TEST_ROOT/output" || fail "uninstalled hook check was not skipped"

echo "scenario 2: missing hooks in an existing global install fail"
ln -s "$source_repo/agents" "$test_home/.agents"
for entry in 'claude/CLAUDE.md' 'codex/AGENTS.md' 'gemini/GEMINI.md'; do
  mkdir -p "$(dirname "$test_home/.$entry")"
  ln -s "$source_repo/dist/$entry" "$test_home/.$entry"
done
ln -s "$source_repo/agents/adapters/claude/settings.json" "$test_home/.claude/settings.json"
mkdir -p "$test_home/.claude/skills"
for skill in product-development-workflow fsd-refactor dotagents-promote usage-guide repo-activity-review; do
  ln -s "$source_repo/agents/skills/owned/$skill" "$test_home/.claude/skills/$skill"
done
run_doctor 1
grep -q '^missing: Codex commit hook link' "$TEST_ROOT/output" || fail "missing hook link was not diagnosed"
[[ ! -e "$test_home/.codex/hooks.json" ]] || fail "doctor installed hooks"

echo "scenario 3: the installed hook passes without assuming trust"
ln -s "$test_home/.agents/adapters/codex/hooks.json" "$test_home/.codex/hooks.json"
run_doctor 0
grep -q '^ok: Codex commit hook link' "$TEST_ROOT/output" || fail "valid hook link was not recognized"
grep -q 'trust is not checked here' "$TEST_ROOT/output" || fail "doctor implied that hooks are trusted"

echo "scenario 4: a dangling hook link fails and is preserved"
unlink "$test_home/.codex/hooks.json"
ln -s "$TEST_ROOT/missing-hooks.json" "$test_home/.codex/hooks.json"
run_doctor 1
grep -q '^broken: Codex commit hook link' "$TEST_ROOT/output" || fail "broken hook link was not diagnosed"
[[ "$(readlink "$test_home/.codex/hooks.json")" == "$TEST_ROOT/missing-hooks.json" ]] || fail "doctor changed the broken link"

echo "scenario 5: a user-owned hook file is preserved"
unlink "$test_home/.codex/hooks.json"
printf '%s\n' '{"hooks": {}}' > "$test_home/.codex/hooks.json"
run_doctor 1
grep -q '^conflict: Codex commit hook link' "$TEST_ROOT/output" || fail "user hook conflict was not diagnosed"
[[ "$(cat "$test_home/.codex/hooks.json")" == '{"hooks": {}}' ]] || fail "doctor changed the user hook file"

echo "scenario 6: a hook from another source is preserved"
mv "$test_home/.codex/hooks.json" "$TEST_ROOT/other-hooks.json"
ln -s "$TEST_ROOT/other-hooks.json" "$test_home/.codex/hooks.json"
run_doctor 1
grep -q '^conflict: Codex commit hook link' "$TEST_ROOT/output" || fail "unexpected hook source was not diagnosed"
[[ "$(readlink "$test_home/.codex/hooks.json")" == "$TEST_ROOT/other-hooks.json" ]] || fail "doctor changed the user hook link"

unlink "$test_home/.codex/hooks.json"
ln -s "$source_repo/agents/adapters/codex/hooks.json" "$test_home/.codex/hooks.json"
for entry in 'claude/CLAUDE.md' 'codex/AGENTS.md' 'gemini/GEMINI.md'; do
  target="$test_home/.$entry"
  echo "scenario: diagnose and preserve $entry entry point problems"
  unlink "$target"
  run_doctor 1
  grep -Fq "missing: host entry point ($target)" "$TEST_ROOT/output" || fail "missing $entry was not diagnosed"
  ln -s "$source_repo/agents/adapters/$entry" "$target"
  run_doctor 1
  grep -Fq "stale: host entry point ($target)" "$TEST_ROOT/output" || fail "thin $entry adapter was not diagnosed"
  [[ "$(readlink "$target")" == "$source_repo/agents/adapters/$entry" ]] || fail "doctor changed a stale entry point"
  unlink "$target"
  ln -s "$TEST_ROOT/missing-entry" "$target"
  run_doctor 1
  grep -Fq "broken: host entry point ($target)" "$TEST_ROOT/output" || fail "broken $entry was not diagnosed"
  [[ -L "$target" ]] || fail "doctor removed a broken entry point"
  unlink "$target"
  printf '%s\n' 'user-owned instructions' > "$target"
  run_doctor 1
  grep -Fq "conflict: host entry point ($target)" "$TEST_ROOT/output" || fail "user $entry conflict was not diagnosed"
  [[ "$(cat "$target")" == 'user-owned instructions' ]] || fail "doctor changed user instructions"
  rm "$target"
  ln -s "$source_repo/dist/$entry" "$target"
done
run_doctor 0

for relative in .claude/settings.json \
  .claude/skills/product-development-workflow .claude/skills/fsd-refactor \
  .claude/skills/dotagents-promote .claude/skills/usage-guide \
  .claude/skills/repo-activity-review \
  .agents/skills/product-development-workflow .agents/skills/fsd-refactor \
  .agents/skills/dotagents-promote .agents/skills/usage-guide \
  .agents/skills/repo-activity-review; do
  target="$test_home/$relative"
  reported_target="$target"
  fix='reinstall from the primary checkout'
  if [[ "$relative" == .agents/* ]]; then
    reported_target="$source_repo/agents/${relative#.agents/}"
    fix='restore the alias in the source checkout'
  fi
  original="$(readlink "$target")"
  echo "scenario: diagnose and preserve $relative link problems"
  unlink "$target"
  run_doctor 1
  grep -F "($reported_target)" "$TEST_ROOT/output" | grep -q '^missing:' || fail "missing $relative was not diagnosed"
  grep -F "($reported_target)" "$TEST_ROOT/output" | grep -Fq "$fix" || fail "missing $relative named the wrong repair"
  [[ ! -e "$target" && ! -L "$target" ]] || fail "doctor created $relative"
  ln -s "$TEST_ROOT/missing-target" "$target"
  run_doctor 1
  grep -F "($reported_target)" "$TEST_ROOT/output" | grep -q '^broken:' || fail "broken $relative was not diagnosed"
  grep -F "($reported_target)" "$TEST_ROOT/output" | grep -Fq "$fix" || fail "broken $relative named the wrong repair"
  [[ "$(readlink "$target")" == "$TEST_ROOT/missing-target" ]] || fail "doctor changed broken $relative"
  unlink "$target"
  printf '%s\n' 'user-owned content' > "$target"
  run_doctor 1
  grep -F "($reported_target)" "$TEST_ROOT/output" | grep -q '^conflict:' || fail "user $relative conflict was not diagnosed"
  [[ "$(cat "$target")" == 'user-owned content' ]] || fail "doctor changed user $relative"
  mv "$target" "$TEST_ROOT/other-target"
  ln -s "$TEST_ROOT/other-target" "$target"
  run_doctor 1
  grep -F "($reported_target)" "$TEST_ROOT/output" | grep -q '^conflict:' || fail "wrong $relative source was not diagnosed"
  [[ "$(readlink "$target")" == "$TEST_ROOT/other-target" ]] || fail "doctor changed the wrong $relative link"
  unlink "$target"
  ln -s "$original" "$target"
done
run_doctor 0

echo "scenario: a missing hook source must not look like an uninstalled checkout"
mv "$source_repo/agents/adapters/codex/hooks.json" "$TEST_ROOT/hooks-source.json"
run_doctor 1
grep -q '^missing: Codex commit hook link source' "$TEST_ROOT/output" || fail "missing hook source behind an intact link was not diagnosed"
unlink "$test_home/.codex/hooks.json"
run_doctor 1
grep -q '^missing: Codex commit hook link source' "$TEST_ROOT/output" || fail "missing hook source was not diagnosed"
mv "$TEST_ROOT/hooks-source.json" "$source_repo/agents/adapters/codex/hooks.json"
ln -s "$source_repo/agents/adapters/codex/hooks.json" "$test_home/.codex/hooks.json"

echo "scenario: recorded installs diagnose missing, broken and replaced .agents roots"
mkdir -p "$TEST_ROOT/state/dotagents"
manifest="$TEST_ROOT/state/dotagents/install.tsv"
printf '%s\t%s\t\n' "$test_home/.agents" "$source_repo/agents" > "$manifest"
cp "$manifest" "$TEST_ROOT/manifest-before"
run_doctor 0
unlink "$test_home/.agents"
run_doctor 1
grep -q '^missing: managed .agents link' "$TEST_ROOT/output" || fail "recorded missing root was treated as uninstalled"
grep -Fq "recorded in $manifest" "$TEST_ROOT/output" || fail "recorded missing root did not name the install record"
[[ ! -e "$test_home/.agents" ]] || fail "doctor created .agents"
ln -s "$TEST_ROOT/missing-agents" "$test_home/.agents"
run_doctor 1
grep -q '^broken: managed .agents link' "$TEST_ROOT/output" || fail "recorded broken root was treated as uninstalled"
[[ "$(readlink "$test_home/.agents")" == "$TEST_ROOT/missing-agents" ]] || fail "doctor changed broken .agents"
unlink "$test_home/.agents"
mkdir -p "$TEST_ROOT/other-agents"
ln -s "$TEST_ROOT/other-agents" "$test_home/.agents"
run_doctor 1
grep -q '^conflict: managed .agents link' "$TEST_ROOT/output" || fail "replaced root was not diagnosed"
[[ "$(readlink "$test_home/.agents")" == "$TEST_ROOT/other-agents" ]] || fail "doctor changed replaced .agents"
unlink "$test_home/.agents"
mkdir "$test_home/.agents"
printf '%s\n' 'user-owned directory' > "$test_home/.agents/note"
run_doctor 1
grep -q '^conflict: managed .agents link' "$TEST_ROOT/output" || fail "user-owned .agents directory was not diagnosed"
[[ "$(cat "$test_home/.agents/note")" == 'user-owned directory' ]] || fail "doctor changed user-owned .agents"
mv "$test_home/.agents" "$TEST_ROOT/user-agents"
ln -s "$source_repo/agents" "$test_home/.agents"
run_doctor 0
cmp -s "$manifest" "$TEST_ROOT/manifest-before" || fail "doctor changed the install manifest"

echo "scenario: recorded source damage is an error"
mv "$source_repo/agents/rules/git.md" "$TEST_ROOT/git-rule.md"
run_doctor 1
grep -q '^missing: dotagents source rules' "$TEST_ROOT/output" || fail "missing source rules were treated as uninstalled"
mv "$TEST_ROOT/git-rule.md" "$source_repo/agents/rules/git.md"

echo "scenario: install records for another home do not imply a global install"
test_home="$TEST_ROOT/uninstalled-home"
mkdir "$test_home"
run_doctor 0
grep -q '^skip: host entry points' "$TEST_ROOT/output" || fail "unrelated install record was used"
test_home="$TEST_ROOT/home"

echo "scenario: missing generated outputs require a build"
mkdir -p "$TEST_ROOT/unbuilt/agents"
cp -R "$REPO_ROOT/agents/rules" "$TEST_ROOT/unbuilt/agents/"
unlink "$test_home/.agents"
ln -s "$TEST_ROOT/unbuilt/agents" "$test_home/.agents"
printf '%s\t%s\t\n' "$test_home/.agents" "$TEST_ROOT/unbuilt/agents" > "$manifest"
run_doctor 1
[[ "$(grep -c '^missing: generated host entry point' "$TEST_ROOT/output")" -eq 3 ]] || fail "missing generated files were not diagnosed"
[[ ! -e "$TEST_ROOT/unbuilt/dist" ]] || fail "doctor generated files"

echo "scenario: every link a real global install records is diagnosed when it goes missing"
# Driven by the installer's own manifest, so a link added to install.sh but
# not to doctor.sh fails here instead of silently going unchecked.
installed_home="$TEST_ROOT/installed-home"
installed_state="$TEST_ROOT/installed-state"
mkdir "$installed_home"
run_installed_doctor() {
  DOTAGENTS_HOME="$installed_home" XDG_STATE_HOME="$installed_state" "$REPO_ROOT/tooling/scripts/doctor.sh" > "$TEST_ROOT/output" 2>&1 < /dev/null
}
DOTAGENTS_HOME="$installed_home" XDG_STATE_HOME="$installed_state" "$REPO_ROOT/tooling/scripts/install.sh" --global > /dev/null
run_installed_doctor || fail "doctor rejected a fresh global install"
while IFS=$'\t' read -r target source _; do
  unlink "$target"
  ! run_installed_doctor || fail "doctor does not diagnose the installed link: $target"
  ln -s "$source" "$target"
done < "$installed_state/dotagents/install.tsv"
run_installed_doctor || fail "doctor rejected the restored global install"

echo "All doctor scenarios passed."
