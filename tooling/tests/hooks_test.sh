#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
HOOK_DIR="$REPO_ROOT/agents/hooks/commit-message"

fail() { echo "test failed: $*" >&2; exit 1; }

command -v jq >/dev/null || fail "jq is required"
for f in check.sh claude-pre-tool-use.sh commit-msg; do
  [[ -x "$HOOK_DIR/$f" ]] || fail "hook is missing or not executable: $f"
done
grep -Fq 'id = "commit-message-check"' "$REPO_ROOT/agents/registry/hooks.toml" || fail "commit-message hook is not registered"
grep -Fq 'claude-pre-tool-use.sh' "$REPO_ROOT/agents/adapters/claude/settings.example.json" || fail "claude settings example does not register the hook"
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
    | "$HOOK_DIR/claude-pre-tool-use.sh" >/dev/null 2>&1
  got=$?
  set -e
  [[ "$got" -eq "$want" ]] || fail "claude hook expected $want got $got for: $cmd"
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

expect_cmd 0 'git status'
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
