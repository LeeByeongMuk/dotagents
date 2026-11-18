#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-project-test.XXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"
trap 'rm -r "$TEST_ROOT"' EXIT
CLI="$REPO_ROOT/tooling/scripts/project.sh"
fail() { echo "test failed: $*" >&2; exit 1; }
run() {
  local expected="$1" actual=0; shift
  "$CLI" "$@" > "$TEST_ROOT/output" 2>&1 || actual=$?
  [[ "$actual" -eq "$expected" ]] || { cat "$TEST_ROOT/output" >&2; fail "exit $actual, expected $expected"; }
}
snapshot() {
  (cd "$1" && find . -print | LC_ALL=C sort && find . -type f -exec cksum {} \; | LC_ALL=C sort && find . -type l -exec readlink {} \; | LC_ALL=C sort) > "$2"
}

echo 'scenario: inspect, doctor and preview are read-only; apply works without global dotagents'
project="$TEST_ROOT/fresh project"
mkdir "$project" "$TEST_ROOT/empty-home"
export HOME="$TEST_ROOT/empty-home"
export DOTAGENTS_HOME="$HOME"
export XDG_STATE_HOME="$TEST_ROOT/unused-state"
snapshot "$project" "$TEST_ROOT/before"
run 0 inspect "$project"
run 1 doctor "$project"
grep -q 'gap: no regular project-local instruction' "$TEST_ROOT/output" || fail 'doctor missed instructions'
run 0 init "$project"
grep -q 'preview only' "$TEST_ROOT/output" || fail 'default init applied'
run 0 init "$project" --dry-run --template nextjs
snapshot "$project" "$TEST_ROOT/after"
cmp "$TEST_ROOT/before" "$TEST_ROOT/after" || fail 'read-only commands wrote project files'
run 0 init "$project" --apply
[[ -f "$project/AGENTS.md" && ! -L "$project/AGENTS.md" ]] || fail 'no regular local AGENTS'
[[ -f "$project/.ai-context/README.md" ]] || fail 'no project context guide'
grep -Fq 'agents/templates/generic/AGENTS.md' "$project/AGENTS.md" || fail 'no template provenance'
grep -Fq 'Verification section' "$project/AGENTS.md" || fail 'no local verification guidance'
[[ ! -e "$project/.agents" && ! -e "$HOME/.agents" && ! -e "$XDG_STATE_HOME" ]] || fail 'global dependency or link created'
run 0 doctor "$project"
grep -q 'no passing checks established' "$TEST_ROOT/output" || fail 'doctor overclaimed validation'
snapshot "$project" "$TEST_ROOT/before"
run 0 init "$project" --template nextjs --apply
run 0 inspect "$project"
snapshot "$project" "$TEST_ROOT/after"
cmp "$TEST_ROOT/before" "$TEST_ROOT/after" || fail 'rerun changed starter files'

echo 'scenario: explicit Next.js template does not select dependencies or tools'
mkdir "$TEST_ROOT/nextjs"
run 0 init "$TEST_ROOT/nextjs" --template nextjs --apply
grep -Fq 'agents/templates/nextjs/AGENTS.md' "$TEST_ROOT/nextjs/AGENTS.md" || fail 'wrong template'
[[ ! -e "$TEST_ROOT/nextjs/package.json" ]] || fail 'init created package configuration'

echo 'scenario: existing instructions, context, docs and config remain byte-identical'
existing="$TEST_ROOT/existing"
mkdir -p "$existing/.ai-context" "$existing/docs" "$existing/.claude"
for file in AGENTS.md CLAUDE.md GEMINI.md .ai-context/README.md docs/domain.md .claude/settings.json; do
  printf 'user-owned %s\n' "$file" > "$existing/$file"
done
snapshot "$existing" "$TEST_ROOT/before"
run 0 init "$existing" --apply
snapshot "$existing" "$TEST_ROOT/after"
cmp "$TEST_ROOT/before" "$TEST_ROOT/after" || fail 'overwrote existing project files'

echo 'scenario: instruction and .agents links are preserved without reading foreign targets'
foreign="$TEST_ROOT/foreign"
linked="$TEST_ROOT/linked"
mkdir "$foreign" "$linked"
printf '# Verification\nforeign instructions\n' > "$foreign/AGENTS.md"
ln -s "$foreign/AGENTS.md" "$linked/AGENTS.md"
ln -s "$foreign" "$linked/.agents"
ln -s "$foreign" "$linked/docs"
ln -s "$foreign/missing" "$linked/CLAUDE.md"
ln -s "$foreign/package.json" "$linked/package.json"
snapshot "$foreign" "$TEST_ROOT/foreign-before"
run 1 doctor "$linked"
grep -q 'gap: no regular project-local instruction' "$TEST_ROOT/output" || fail 'followed foreign instructions'
run 0 init "$linked" --apply
[[ -L "$linked/AGENTS.md" && -L "$linked/.agents" && -L "$linked/CLAUDE.md" ]] || fail 'replaced a link'
snapshot "$foreign" "$TEST_ROOT/foreign-after"
cmp "$TEST_ROOT/foreign-before" "$TEST_ROOT/foreign-after" || fail 'mutated foreign link targets'

echo 'scenario: context directory escape is rejected atomically'
escape="$TEST_ROOT/escape"
mkdir "$escape"
ln -s "$foreign" "$escape/.ai-context"
snapshot "$escape" "$TEST_ROOT/before"
run 1 init "$escape" --apply
snapshot "$escape" "$TEST_ROOT/after"
cmp "$TEST_ROOT/before" "$TEST_ROOT/after" || fail 'partial write before symlink rejection'
ln -s "$existing" "$TEST_ROOT/alias"
run 1 init "$TEST_ROOT/alias/" --apply
mkdir "$TEST_ROOT/parent"
ln -s "$TEST_ROOT/parent" "$TEST_ROOT/parent-alias"
mkdir "$TEST_ROOT/parent/child"
run 1 init "$TEST_ROOT/parent-alias/child" --apply
[[ ! -e "$TEST_ROOT/parent/child/AGENTS.md" ]] || fail 'followed symlink ancestor'
run 1 init "$HOME" --apply
run 1 init "$REPO_ROOT" --apply
run 1 init / --apply
run 1 init "$TEST_ROOT/not-created" --apply
[[ ! -e "$TEST_ROOT/not-created" ]] || fail 'created unselected parent directory'

echo 'scenario: another checkout and its descendants from the same repository are protected'
source_main="$TEST_ROOT/source-main"
source_worktree="$TEST_ROOT/source-worktree"
mkdir -p "$source_main/tooling/scripts" "$source_main/agents/templates/context-docs" "$source_main/agents/templates/generic"
cp "$CLI" "$source_main/tooling/scripts/project.sh"
cp "$REPO_ROOT/agents/templates/generic/AGENTS.md" "$source_main/agents/templates/generic/AGENTS.md"
cp "$REPO_ROOT/agents/templates/context-docs/project-readme.md" "$source_main/agents/templates/context-docs/project-readme.md"
git -C "$source_main" init -q
git -C "$source_main" add .
git -C "$source_main" -c user.name=Fixture -c user.email=fixture@example.test -c core.hooksPath=/dev/null commit -qm fixture
git -C "$source_main" worktree add --detach "$source_worktree" HEAD >/dev/null 2>&1
snapshot "$source_main" "$TEST_ROOT/before"
old_cli="$CLI"
CLI="$source_worktree/tooling/scripts/project.sh"
run 1 init "$source_main" --apply
grep -q 'including linked worktrees' "$TEST_ROOT/output" || fail 'did not diagnose shared source repository'
run 1 init "$source_main/agents" --apply
snapshot "$source_main" "$TEST_ROOT/after"
cmp "$TEST_ROOT/before" "$TEST_ROOT/after" || fail 'modified the primary source checkout'
CLI="$old_cli"

echo 'scenario: unsupported templates and context file conflicts make no partial changes'
invalid="$TEST_ROOT/invalid"
mkdir "$invalid"
run 1 init "$invalid" --template unknown --apply
[[ ! -e "$invalid/AGENTS.md" ]] || fail 'invalid template wrote files'
printf 'user file\n' > "$invalid/.ai-context"
snapshot "$invalid" "$TEST_ROOT/before"
run 1 init "$invalid" --apply
snapshot "$invalid" "$TEST_ROOT/after"
cmp "$TEST_ROOT/before" "$TEST_ROOT/after" || fail 'context conflict wrote files'

echo 'scenario: failed second publication rolls back newly created files and directories'
mkdir "$TEST_ROOT/failure" "$TEST_ROOT/bin"
real_ln="$(command -v ln)"
cat > "$TEST_ROOT/bin/ln" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == */README.md ]]; then exit 9; fi
exec "$REAL_LN" "$@"
EOF
chmod +x "$TEST_ROOT/bin/ln"
export REAL_LN="$real_ln"
snapshot "$TEST_ROOT/failure" "$TEST_ROOT/before"
PATH="$TEST_ROOT/bin:$PATH" run 9 init "$TEST_ROOT/failure" --apply
snapshot "$TEST_ROOT/failure" "$TEST_ROOT/after"
cmp "$TEST_ROOT/before" "$TEST_ROOT/after" || fail 'failed init left partial files or staging data'

echo 'scenario: verification evidence is reported without executing or exposing script commands'
evidence="$TEST_ROOT/evidence"
mkdir -p "$evidence/docs/context"
printf '# Project rules\n' > "$evidence/CLAUDE.md"
cat > "$evidence/package.json" <<'EOF'
{"scripts":{"test":"touch SHOULD_NOT_EXIST","lint:ci":"echo PRIVATE_COMMAND_CONTENT","dev":"echo unrelated"}}
EOF
printf 'lock evidence\n' > "$evidence/pnpm-lock.yaml"
snapshot "$evidence" "$TEST_ROOT/before"
run 0 doctor "$evidence"
grep -q 'verification candidate: package.json script test' "$TEST_ROOT/output" || fail 'missed package script'
grep -q 'package manager evidence: pnpm-lock.yaml' "$TEST_ROOT/output" || fail 'missed lockfile'
! grep -Eq 'PRIVATE_COMMAND_CONTENT|SHOULD_NOT_EXIST|script dev' "$TEST_ROOT/output" || fail 'exposed command contents or unrelated metadata'
snapshot "$evidence" "$TEST_ROOT/after"
cmp "$TEST_ROOT/before" "$TEST_ROOT/after" || fail 'inspect executed project scripts'
printf '{invalid\n' > "$evidence/package.json"
run 1 doctor "$evidence"
grep -q 'package.json is invalid' "$TEST_ROOT/output" || fail 'invalid package metadata accepted'
# A verification heading must not hide an explicitly malformed scripts field.
printf '# Verification\n' > "$evidence/CLAUDE.md"
for value in false null '[]'; do
  printf '{"scripts":%s}\n' "$value" > "$evidence/package.json"
  run 1 doctor "$evidence"
  grep -q 'scripts is not an object' "$TEST_ROOT/output" || fail 'invalid scripts field accepted'
done

echo 'All project readiness scenarios passed.'
