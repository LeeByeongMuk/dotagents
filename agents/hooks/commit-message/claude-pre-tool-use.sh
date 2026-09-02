#!/usr/bin/env bash
# Claude Code PreToolUse hook (matcher: Bash). Blocks `git commit` whose message
# violates agents/rules/git.md. Exit 2 blocks the tool call; exit 0 allows it.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
input="$(cat)"
command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
[[ -n "$command" ]] || exit 0

# Only act on git commit invocations.
printf '%s' "$command" | grep -Eq '(^|[[:space:];&|(])git([[:space:]]+-[A-Za-z-]+([[:space:]=][^[:space:]]+)?)*[[:space:]]+commit([[:space:]]|$)' || exit 0

block() {
  echo "$*" >&2
  exit 2
}

# Commits that reuse an existing message are not checked.
if printf '%s' "$command" | grep -Eq -- '--no-edit|--reuse-message|--reedit-message|--fixup|--squash|(^|[[:space:]])-[cC][[:space:]]'; then
  exit 0
fi

tmp="$(mktemp "${TMPDIR:-/tmp}/dotagents-commit.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

if [[ "$command" =~ \<\<-?[\'\"]?([A-Za-z_][A-Za-z0-9_]*)[\'\"]? ]]; then
  marker="${BASH_REMATCH[1]}"
  printf '%s\n' "$command" | awk -v m="$marker" '
    body && $0 ~ "^[[:space:]]*" m "[[:space:]]*$" { exit }
    body { print }
    !body && index($0, "<<") { body = 1 }
  ' > "$tmp"
elif [[ "$command" =~ (^|[[:space:]])(-[a-zA-Z]*m|--message)([[:space:]]|=) ]]; then
  rest="$command"
  count=0
  m_re="(^|[[:space:]])(-[a-zA-Z]*m|--message)[[:space:]]*=?[[:space:]]*(\"(([^\"\\\\]|\\\\.)*)\"|'([^']*)'|([^[:space:]\"']+))"
  while [[ "$rest" =~ $m_re ]]; do
    part="${BASH_REMATCH[4]:-${BASH_REMATCH[6]:-${BASH_REMATCH[7]}}}"
    [[ $count -gt 0 ]] && printf '\n' >> "$tmp"
    printf '%s\n' "$part" >> "$tmp"
    count=$((count + 1))
    rest="${rest#*"${BASH_REMATCH[0]}"}"
  done
  [[ $count -gt 0 ]] || block "could not parse the -m message; use -m \"...\" or a heredoc."
elif [[ "$command" =~ (-F|--file)[[:space:]]*=?[[:space:]]*([^[:space:]\"\']+) ]]; then
  file="${BASH_REMATCH[2]}"
  [[ "$file" == /* ]] || file="${cwd:-$PWD}/$file"
  [[ -f "$file" ]] || block "commit message file is not readable before the command runs: $file. Pass the message with -m or a heredoc."
  cp "$file" "$tmp"
else
  block "could not find the commit message in the command. Pass it with -m \"...\" or -m \"\$(cat <<'EOF' ... EOF)\" so it can be validated against agents/rules/git.md."
fi

if ! DOTAGENTS_REPO_DIR="${cwd:-$PWD}" "$here/check.sh" "$tmp" 2> "$tmp.err"; then
  block "$(cat "$tmp.err")"
fi
rm -f "$tmp.err"
exit 0
