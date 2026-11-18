#!/usr/bin/env bash
# Validate a commit message against agents/rules/git.md defaults.
# Usage: check.sh [MESSAGE_FILE]   (reads stdin when no file is given)
# Environment: DOTAGENTS_REPO_DIR selects the repository whose local policy is honored.
set -euo pipefail

message_file="${1:-/dev/stdin}"
repo_dir="${DOTAGENTS_REPO_DIR:-$PWD}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

for candidate in C.UTF-8 en_US.UTF-8; do
  if locale -a 2>/dev/null | grep -qix "${candidate//UTF-8/utf8}\|$candidate"; then
    export LC_ALL="$candidate"
    break
  fi
done

fail() {
  echo "commit message rejected: $*" >&2
  echo "see agents/rules/git.md (Commit messages) or set 'git config dotagents.commitCheck false' when the project defines its own convention." >&2
  exit 1
}

is_husky_dispatcher() {
  local path="$1"
  [[ "$path" == */_/commit-msg && -f "${path%/*}/h" ]] || return 1
  # Husky 9 writes a dispatcher for each Git hook, even with no project hook.
  cmp -s "$path" <(printf '%s\n%s' '#!/usr/bin/env sh' '. "$(dirname "$0")/h"') ||
    cmp -s "$path" <(printf '%s\n%s' '#!/usr/bin/env sh' '. "${0%/*}/h"')
}

# Project policy comes first: skip when the project enforces its own convention.
if [[ -d "$repo_dir" ]]; then
  if [[ "$(git -C "$repo_dir" config --bool --get dotagents.commitCheck 2>/dev/null || echo true)" == "false" ]]; then
    exit 0
  fi
  top="$(git -C "$repo_dir" rev-parse --show-toplevel 2>/dev/null || echo "$repo_dir")"
  for marker in commitlint.config.js commitlint.config.cjs commitlint.config.mjs commitlint.config.ts \
                .commitlintrc .commitlintrc.json .commitlintrc.yml .commitlintrc.yaml .commitlintrc.js \
                .gitlint; do
    [[ -f "$top/$marker" ]] && exit 0
  done
  # Run from the worktree root so relative core.hooksPath values resolve as
  # they do for Git. The default hook can live in a linked worktree's common dir.
  hook="$(git -C "$top" rev-parse --git-path hooks/commit-msg 2>/dev/null || echo .git/hooks/commit-msg)"
  [[ "$hook" == /* ]] || hook="$top/$hook"
  if [[ -f "$hook" ]] && is_husky_dispatcher "$hook"; then
    hook="${hook%/_/commit-msg}/commit-msg"
  fi
  for candidate in "$hook" "$top/.husky/commit-msg"; do
    [[ -f "$candidate" ]] || continue
    # A symlink or copy of our own wrapper still uses the shared convention.
    [[ "$candidate" -ef "$here/commit-msg" ]] && continue
    cmp -s "$candidate" "$here/commit-msg" && continue
    exit 0
  done
fi

lines=()
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" == \#* ]] && continue
  lines+=("$line")
done < "$message_file"

# Trim leading blank lines.
while [[ ${#lines[@]} -gt 0 && -z "${lines[0]//[[:space:]]/}" ]]; do
  lines=("${lines[@]:1}")
done
[[ ${#lines[@]} -gt 0 ]] || fail "message is empty"

header="${lines[0]}"
types='feat|fix|refactor|perf|docs|test|build|ci|chore|revert'
header_re="^($types)(\([^()[:space:]]+\))?!?: [^[:space:]].*$"

[[ "$header" =~ $header_re ]] || fail "header must match '<type>(<scope>)!: <summary>' with type in {${types//|/, }}: '$header'"
if [[ ${#header} -gt 72 ]]; then
  original_header="${header#revert: }"
  [[ "$header" == 'revert: '* && "$original_header" =~ $header_re && ${#original_header} -le 72 ]] \
    || fail "header exceeds 72 characters (${#header})"
fi
[[ "$header" != *. ]] || fail "header must not end with a period"
summary="${header#*: }"
[[ ! "$summary" =~ ^[A-Z] ]] || fail "English summary must start with a lowercase letter"
[[ ! "$summary" =~ ^(added|fixed|updated|changed|removed|refactored|improved)[[:space:]] ]] || fail "summary must use the imperative mood (add, fix, update)"

if [[ ${#lines[@]} -gt 1 ]]; then
  [[ -z "${lines[1]//[[:space:]]/}" ]] || fail "second line must be blank"
fi

forbidden_re='(this commit|이 커밋은|이 커밋에서는|comprehensive|seamless(ly)?|robust|대폭 개선|완벽하게)'
for line in "${lines[@]}"; do
  lowered="$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')"
  [[ ! "$lowered" =~ $forbidden_re ]] || fail "narrative or inflated wording is not allowed: '$line'"
  [[ ! "$line" =~ ^[[:space:]]*(-|\*|#+)[[:space:]] ]] || fail "bullets and markdown headings are not allowed: '$line'"
  [[ "$line" != *'**'* ]] || fail "bold markup is not allowed: '$line'"
  [[ ${#line} -le 100 ]] || fail "line exceeds 100 characters: '${line:0:40}...'"
done
exit 0
