#!/usr/bin/env bash
# Validate a commit message against agents/rules/git.md defaults.
# Usage: check.sh [MESSAGE_FILE]   (reads stdin when no file is given)
# Environment: DOTAGENTS_REPO_DIR selects the repository whose local policy is honored.
set -euo pipefail

message_file="${1:-/dev/stdin}"
repo_dir="${DOTAGENTS_REPO_DIR:-$PWD}"

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

# Project policy comes first: skip when the project enforces its own convention.
if [[ -d "$repo_dir" ]]; then
  if [[ "$(git -C "$repo_dir" config --bool --get dotagents.commitCheck 2>/dev/null || echo true)" == "false" ]]; then
    exit 0
  fi
  top="$(git -C "$repo_dir" rev-parse --show-toplevel 2>/dev/null || echo "$repo_dir")"
  for marker in commitlint.config.js commitlint.config.cjs commitlint.config.mjs commitlint.config.ts \
                .commitlintrc .commitlintrc.json .commitlintrc.yml .commitlintrc.yaml .commitlintrc.js \
                .gitlint .husky/commit-msg .git/hooks/commit-msg; do
    [[ -f "$top/$marker" ]] && exit 0
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
[[ ${#header} -le 72 ]] || fail "header exceeds 72 characters (${#header})"
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
