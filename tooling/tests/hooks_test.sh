#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
HOOK_DIR="$REPO_ROOT/agents/hooks/commit-message"

fail() { echo "test failed: $*" >&2; exit 1; }

command -v jq >/dev/null || fail "jq is required"
for f in check.sh pre-tool-use.sh commit-msg; do
  [[ -x "$HOOK_DIR/$f" ]] || fail "hook is missing or not executable: $f"
done
grep -Fq 'id = "commit-message-check"' "$REPO_ROOT/agents/registry/hooks.toml" || fail "commit-message hook is not registered"
for settings in settings.json settings.example.json; do
  jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command | endswith("/commit-message/pre-tool-use.sh"))' \
    "$REPO_ROOT/agents/adapters/claude/$settings" >/dev/null || fail "claude $settings does not register the hook"
done
jq -e '.hooks.PreToolUse[] | select(.matcher == "^Bash$") | .hooks[] | select(.command | endswith("/commit-message/pre-tool-use.sh"))' \
  "$REPO_ROOT/agents/adapters/codex/hooks.json" >/dev/null || fail "codex hooks.json does not register the hook"
grep -Fq 'rules/git.md' "$REPO_ROOT/agents/adapters/claude/CLAUDE.md" || fail "claude adapter does not point at git.md"
grep -Fq 'rules/git.md' "$REPO_ROOT/agents/adapters/codex/AGENTS.md" || fail "codex adapter does not point at git.md"
grep -Fq 'rules/git.md' "$REPO_ROOT/agents/adapters/gemini/GEMINI.md" || fail "gemini adapter does not point at git.md"

work="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-hooks.XXXXXX")"
trap 'rm -rf "$work"' EXIT
git init -q "$work/repo"
repo="$work/repo"

expect_msg() {
  local want="$1" msg="$2" got
  set +e
  printf '%s\n' "$msg" | DOTAGENTS_REPO_DIR="$repo" "$HOOK_DIR/check.sh" >/dev/null 2>&1
  got=$?
  set -e
  [[ "$got" -eq "$want" ]] || fail "check.sh expected $want got $got for: $msg"
}

expect_cmd() {
  local want="$1" cmd="$2" got
  set +e
  jq -cn --arg c "$cmd" --arg d "$repo" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' \
    | "$HOOK_DIR/pre-tool-use.sh" >/dev/null 2>&1
  got=$?
  set -e
  [[ "$got" -eq "$want" ]] || fail "pre-tool-use hook expected $want got $got for: $cmd"
}

expect_msg 0 'feat(auth): add refresh token rotation'
expect_msg 0 'docs: 설치 절차에 dry-run 옵션 설명 추가'
expect_msg 0 'feat(api)!: drop v1 endpoints'
expect_msg 0 $'fix: handle empty scope\n\nExplain why.\n\nFixes #12'
expect_msg 1 'Add feature'
expect_msg 1 'feat: Add feature'
expect_msg 1 'feat: add feature.'
expect_msg 1 'feat: added feature'
expect_msg 1 'wip'
expect_msg 1 $'feat: x\nbody without blank line'
expect_msg 1 $'feat: x\n\nThis commit introduces a robust helper'
expect_msg 1 $'feat: x\n\n- bullet list'
expect_msg 1 $'feat: x\n\n**bold**'

git -C "$repo" config dotagents.commitCheck false
expect_msg 0 'project convention wins'
git -C "$repo" config --unset dotagents.commitCheck
touch "$repo/.gitlint"
expect_msg 0 'project linter wins'
rm "$repo/.gitlint"

# Installed as the repository's own commit-msg hook, the wrapper still checks.
ln -s "$HOOK_DIR/commit-msg" "$repo/.git/hooks/commit-msg"
if git -C "$repo" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m 'Add thing' >/dev/null 2>&1; then
  fail "commit-msg hook accepted an invalid message"
fi
git -C "$repo" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m 'chore: verify the commit hook' >/dev/null 2>&1 \
  || fail "commit-msg hook rejected a valid message"
rm "$repo/.git/hooks/commit-msg"

expect_cmd 0 'git status'
expect_cmd 0 "printf '%s\\n' 'git' 'commit'"
expect_cmd 0 'printf "%s\n" "git" "commit"'
expect_cmd 0 "echo 'git' 'commit'"
expect_cmd 2 'command git commit -m "Add thing"'
expect_cmd 2 'env TEST_VALUE=literal git commit -m "Add thing"'
expect_cmd 2 'TEST_VALUE=literal git commit -m "Add thing"'
expect_cmd 2 'sudo -n git commit -m "Add thing"'
expect_cmd 2 'echo ready; git commit -m "Add thing"'
expect_cmd 2 '(git commit -m "Add thing")'
expect_cmd 2 'if true; then git commit -m "Add thing"; fi'
expect_cmd 2 'if false; then echo skip; else git commit -m "Add thing"; fi'
expect_cmd 2 'if git commit -m "Add thing"; then echo done; fi'
expect_cmd 2 'if false; then echo skip; elif git commit -m "Add thing"; then echo done; fi'
expect_cmd 2 'while true; do git commit -m "Add thing"; done'
expect_cmd 2 'while git commit -m "Add thing"; do echo done; done'
expect_cmd 2 'until git commit -m "Add thing"; do echo retry; done'
expect_cmd 0 'git commit -m "feat: add thing"'
expect_cmd 0 'git commit -am "fix: handle empty input"'
expect_cmd 0 'git commit --message="chore: bump deps"'
expect_cmd 0 'git add -A && git commit -m "fix(x): handle empty"'
expect_cmd 0 'git -C sub commit -m "chore: bump"'
expect_cmd 0 'git commit --amend --no-edit'
expect_cmd 0 $'git commit -m "$(cat <<\'EOF\'\nfeat: add thing\n\nWhy it changed.\nEOF\n)"'
expect_cmd 2 'git commit -m "Add thing"'
expect_cmd 2 "git commit -m 'Add thing'"
expect_cmd 2 'git commit -am "handle empty input"'
expect_cmd 2 'git commit -m "feat: x" -m "This commit introduces things"'
expect_cmd 2 $'git commit -m "$(cat <<\'EOF\'\nAdd thing\nEOF\n)"'
expect_cmd 2 'git commit'
expect_cmd 2 'git commit -F missing.txt'

# Only the commit's own arguments can skip the check.
expect_cmd 2 'git -c commit.gpgsign=false commit -m "Add thing"'
expect_cmd 2 'git -C sub commit -m "Add thing"'
expect_cmd 2 'git commit -m "Add thing" && git merge --no-edit topic'
expect_cmd 2 'git commit -m "Add -c flag support"'
expect_cmd 0 'git commit -C HEAD --amend'
expect_cmd 0 'git commit --fixup=HEAD'
expect_cmd 0 $'git commit --amend \\\n  --no-edit'

# Git's global -C selects the target repository's policy, not the caller's.
# Keep the policies opposite so validating the wrong directory changes results.
target="$work/target repo"
git init -q "$target"
mkdir "$target/nested"
git -C "$repo" config dotagents.commitCheck false
git -C "$target" config dotagents.commitCheck true
expect_cmd 2 "git -C '$target' commit -m 'Add thing'"
expect_cmd 2 'git -C "../target repo" commit -m "Add thing"'
expect_cmd 2 'git -c "test.note=words with spaces" -C "../target repo" commit -m "Add thing"'
expect_cmd 2 'git -C .. -C "target repo" -C nested commit -m "Add thing"'
expect_cmd 2 'git -C.. -Ctarget\ repo -C "" commit -m "Add thing"'
expect_cmd 2 $'git -C .. \\\n  -C "target repo" commit -m "Add thing"'
expect_cmd 0 'git -C "../target repo" commit -C HEAD --amend'
git -C "$repo" config dotagents.commitCheck true
git -C "$target" config dotagents.commitCheck false
expect_cmd 0 "git -C '$target' commit -m 'Add thing'"
expect_cmd 0 'git -C .. -C "target repo" commit -m "Add thing"'
git -C "$target" config dotagents.commitCheck true

# Relative -F paths are resolved after all global -C options, including quotes.
# A different file at the caller's path must not determine the result.
printf '%s\n' 'Add thing' > "$repo/message.txt"
printf '%s\n' 'fix: use the target message' > "$target/message.txt"
expect_cmd 0 'git -C "../target repo" commit -F message.txt'
printf '%s\n' 'fix: use the caller message' > "$repo/message.txt"
printf '%s\n' 'Add thing' > "$target/message.txt"
expect_cmd 2 'git -C "../target repo" commit --file=message.txt'
printf '%s\n' 'fix: read a quoted path' > "$target/nested/commit message.txt"
expect_cmd 0 'git -C .. -C "target repo" -C nested commit -F "commit message.txt"'
expect_cmd 0 "git -C '$target' -C nested commit --file='commit message.txt'"
expect_cmd 0 'git -C "../target repo" -C nested commit -Fcommit\ message.txt'
expect_cmd 0 $'# git commit -m "Add thing"\ngit -C "../target repo" commit -m "fix: keep comments inert"'
expect_cmd 0 $'cat <<\'EOF\'\n한글 문서\nEOF\ngit -C "../target repo" commit -m "fix: keep heredoc offsets"'
large_body="$(printf '%10000s' '' | tr ' ' x)"
expect_cmd 2 $'cat <<\'EOF\'\n'"$large_body"$'\nEOF\ngit -C "../target repo" commit -m "Add thing"'
expect_cmd 2 $'git -C "../target repo" commit -F - <<\'EOF\'\nAdd thing\nEOF'

# Expansions cannot establish a repository policy without executing shell code.
expect_cmd 2 'git -C "$target" commit -m "fix: use a literal directory"'
expect_cmd 2 'git -C $(pwd) commit -m "Add thing"'
expect_cmd 2 'git -C `pwd` commit -m "Add thing"'
expect_cmd 2 'git -C $(printf "%s" "$(pwd)") commit -m "Add thing"'
expect_cmd 2 'git commit -F $(printf message.txt)'
expect_cmd 2 'git commit -F `printf message.txt`'
probe="$work/must-not-run"
expect_cmd 2 "git -C \"\$(touch '$probe')\" commit -m 'fix: use a literal directory'"
expect_cmd 2 "git -C \$(touch '$probe'; pwd) commit -m 'Add thing'"
expect_cmd 2 "git commit -F \$(touch '$probe'; printf message.txt)"
[[ ! -e "$probe" ]] || fail "pre-tool-use hook executed a path substitution"
git -C "$repo" config --unset dotagents.commitCheck

# Codex sends the same fields plus its own extensions.
set +e
jq -cn --arg c 'git commit -m "Add thing"' --arg d "$repo" \
  '{session_id:"s",turn_id:"t",hook_event_name:"PreToolUse",model:"m",tool_name:"Bash",tool_use_id:"u",tool_input:{command:$c},cwd:$d}' \
  | "$HOOK_DIR/pre-tool-use.sh" >/dev/null 2>&1
got=$?
set -e
[[ "$got" -eq 2 ]] || fail "pre-tool-use hook did not block a Codex payload (got $got)"

# A rejected commit leaves no temporary files behind.
leak_dir="$work/tmp"
mkdir -p "$leak_dir"
jq -cn --arg c 'git commit -m "Add thing"' --arg d "$repo" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' \
  | TMPDIR="$leak_dir" "$HOOK_DIR/pre-tool-use.sh" >/dev/null 2>&1 || true
# Git may create its own platform cache (for example xcrun_db on macOS).
# Only files owned by this hook count as leaks.
leaked_messages=("$leak_dir"/dotagents-commit.*)
[[ ! -e "${leaked_messages[0]}" ]] || fail "rejected commit left temporary files"

# A heredoc that writes an unrelated file must not supply the commit message.
expect_cmd 0 $'cat > a.js <<\'EOF\'\nvar x = 1;\nEOF\ngit commit -m "fix: correct a typo"'
expect_cmd 0 $'python3 - <<\'PY\'\nprint("hello")\nPY\ngit commit -m "chore: regenerate output"'
expect_cmd 0 $'cat > a.md <<\'EOF\'\nAdd thing\nEOF\ngit add -A && git commit -m "docs: add a note"'
# The message itself is still validated when it arrives after a heredoc.
expect_cmd 2 $'cat > a.js <<\'EOF\'\nvar x = 1;\nEOF\ngit commit -m "Add thing"'
# A commit written inside a heredoc body is not the command being run.
expect_cmd 0 $'cat > release.sh <<\'EOF\'\ngit commit -m "Add thing"\nEOF\necho done'
# A commit that reads its message from stdin still resolves the heredoc.
expect_cmd 0 $'git commit -F - <<\'EOF\'\nfeat: add thing\nEOF'
expect_cmd 2 $'git commit -F - <<\'EOF\'\nAdd thing\nEOF'

echo "hooks test passed"
