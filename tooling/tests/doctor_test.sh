#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-doctor-test.XXXXXX")"
trap 'rm -r "$TEST_ROOT"' EXIT

fail() { echo "test failed: $*" >&2; exit 1; }

run_doctor() {
  local expected="$1" actual=0
  DOTAGENTS_HOME="$test_home" "$REPO_ROOT/tooling/scripts/doctor.sh" > "$TEST_ROOT/output" 2>&1 || actual=$?
  [[ "$actual" -eq "$expected" ]] || fail "doctor returned $actual, expected $expected"
}

test_home="$TEST_ROOT/home"
mkdir -p "$test_home/.codex"

echo "scenario 1: an uninstalled checkout needs no global hooks"
run_doctor 0
grep -q '^skip: Codex commit hook link' "$TEST_ROOT/output" || fail "uninstalled hook check was not skipped"

echo "scenario 2: missing hooks in an existing global install fail"
ln -s "$REPO_ROOT/agents" "$test_home/.agents"
for entry in 'claude/CLAUDE.md' 'codex/AGENTS.md' 'gemini/GEMINI.md'; do
  mkdir -p "$(dirname "$test_home/.$entry")"
  ln -s "$REPO_ROOT/dist/$entry" "$test_home/.$entry"
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
grep -q '^conflict: Codex hooks' "$TEST_ROOT/output" || fail "user hook conflict was not diagnosed"
[[ "$(cat "$test_home/.codex/hooks.json")" == '{"hooks": {}}' ]] || fail "doctor changed the user hook file"

echo "scenario 6: a hook from another source is preserved"
mv "$test_home/.codex/hooks.json" "$TEST_ROOT/other-hooks.json"
ln -s "$TEST_ROOT/other-hooks.json" "$test_home/.codex/hooks.json"
run_doctor 1
grep -q '^conflict: Codex hooks' "$TEST_ROOT/output" || fail "unexpected hook source was not diagnosed"
[[ "$(readlink "$test_home/.codex/hooks.json")" == "$TEST_ROOT/other-hooks.json" ]] || fail "doctor changed the user hook link"

unlink "$test_home/.codex/hooks.json"
ln -s "$REPO_ROOT/agents/adapters/codex/hooks.json" "$test_home/.codex/hooks.json"
for entry in 'claude/CLAUDE.md' 'codex/AGENTS.md' 'gemini/GEMINI.md'; do
  target="$test_home/.$entry"
  echo "scenario: diagnose and preserve $entry entry point problems"
  unlink "$target"
  run_doctor 1
  grep -Fq "missing: host entry point ($target)" "$TEST_ROOT/output" || fail "missing $entry was not diagnosed"
  ln -s "$REPO_ROOT/agents/adapters/$entry" "$target"
  run_doctor 1
  grep -Fq "stale: host entry point ($target)" "$TEST_ROOT/output" || fail "thin $entry adapter was not diagnosed"
  [[ "$(readlink "$target")" == "$REPO_ROOT/agents/adapters/$entry" ]] || fail "doctor changed a stale entry point"
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
  ln -s "$REPO_ROOT/dist/$entry" "$target"
done
run_doctor 0

echo "scenario: missing generated outputs require a build"
mkdir -p "$TEST_ROOT/unbuilt/agents"
cp -R "$REPO_ROOT/agents/rules" "$TEST_ROOT/unbuilt/agents/"
unlink "$test_home/.agents"
ln -s "$TEST_ROOT/unbuilt/agents" "$test_home/.agents"
run_doctor 1
[[ "$(grep -c '^missing: generated host entry point' "$TEST_ROOT/output")" -eq 3 ]] || fail "missing generated files were not diagnosed"
[[ ! -e "$TEST_ROOT/unbuilt/dist" ]] || fail "doctor generated files"

echo "All doctor scenarios passed."
