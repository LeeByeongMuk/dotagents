#!/usr/bin/env bash
# PreToolUse hook for Claude Code and Codex (matcher: Bash). Both hosts send
# tool_input.command and cwd on stdin and treat exit 2 as a block. Blocks a
# `git commit` whose message violates agents/rules/git.md; exit 0 allows it.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
input="$(cat)"
command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
[[ -n "$command" ]] || exit 0

git_commit_re='(^|[[:space:];&|(])git([[:space:]]+-[A-Za-z-]+([[:space:]=][^[:space:]]+)?)*[[:space:]]+commit([[:space:]]|$)'

# A heredoc body is data, not command text. Blank those lines out, keeping line
# numbers, so a `git commit` or an -m flag written inside a heredoc body is not
# mistaken for the command being run.
code_only="$(printf '%s\n' "$command" | awk '
  {
    if (in_body) {
      probe = $0
      sub(/^[[:space:]]+/, "", probe)
      sub(/[[:space:]]+$/, "", probe)
      if (probe == marker) { in_body = 0 }
      print ""
      next
    }
    print
    if (match($0, /<<-?['"'"'"]?[A-Za-z_][A-Za-z0-9_]*['"'"'"]?/)) {
      marker = substr($0, RSTART, RLENGTH)
      sub(/^<<-?/, "", marker)
      gsub(/['"'"'"]/, "", marker)
      in_body = 1
    }
  }')"

# Only act on git commit invocations that are actually run.
start_line="$(printf '%s\n' "$code_only" | grep -nE "$git_commit_re" | head -1 | cut -d: -f1 || true)"
[[ -n "$start_line" ]] || exit 0

# Everything from the commit onwards, so an earlier heredoc that wrote a file
# cannot supply the message.
segment="$(printf '%s\n' "$command" | sed -n "${start_line},\$p")"

block() {
  echo "$*" >&2
  exit 2
}

# Commits that reuse an existing message are not checked. Only the commit's own
# arguments decide this: its line, with backslash continuations joined, after
# `git ... commit`, without quoted text, up to the next command separator. Git
# options before `commit` such as -c or -C and flags of later commands do not.
commit_line="$(printf '%s\n' "$code_only" | sed -n "${start_line},\$p" | awk '!done { if (sub(/\\$/, "")) { printf "%s ", $0 } else { print; done = 1 } }')"
commit_args=""
if [[ "$commit_line" =~ $git_commit_re ]]; then
  commit_args="${commit_line#*"${BASH_REMATCH[0]}"}"
fi
commit_args="$(printf '%s' "$commit_args" | sed -E -e 's/"([^"\\]|\\.)*"//g' -e "s/'[^']*'//g")"
commit_args="${commit_args%%[;&|]*}"
if printf '%s' "$commit_args" | grep -Eq -- '(^|[[:space:]])(--no-edit|--reuse-message|--reedit-message|--fixup|--squash|-[cC])([[:space:]=]|$)'; then
  exit 0
fi

tmp="$(mktemp "${TMPDIR:-/tmp}/dotagents-commit.XXXXXX")"
trap 'rm -f "$tmp" "$tmp.err"' EXIT

read_heredoc_body() {
  local text="$1" marker
  [[ "$text" =~ \<\<-?[\'\"]?([A-Za-z_][A-Za-z0-9_]*)[\'\"]? ]] || return 1
  marker="${BASH_REMATCH[1]}"
  printf '%s\n' "$text" | awk -v m="$marker" '
    body && $0 ~ "^[[:space:]]*" m "[[:space:]]*$" { exit }
    body { print }
    !body && index($0, "<<") { body = 1 }
  ' > "$tmp"
}

message_source=""
if [[ "$segment" =~ (^|[[:space:]])(-[a-zA-Z]*m|--message)([[:space:]]|=) ]]; then
  rest="$segment"
  count=0
  literal=1
  m_re="(^|[[:space:]])(-[a-zA-Z]*m|--message)[[:space:]]*=?[[:space:]]*(\"(([^\"\\\\]|\\\\.)*)\"|'([^']*)'|([^[:space:]\"']+))"
  while [[ "$rest" =~ $m_re ]]; do
    part="${BASH_REMATCH[4]:-${BASH_REMATCH[6]:-${BASH_REMATCH[7]}}}"
    # A substitution such as -m "$(cat <<'EOF' ... EOF)" carries the message in
    # its heredoc, not in the flag argument.
    if [[ "$part" == *'<<'* ]]; then
      literal=0
      break
    fi
    [[ $count -gt 0 ]] && printf '\n' >> "$tmp"
    printf '%s\n' "$part" >> "$tmp"
    count=$((count + 1))
    rest="${rest#*"${BASH_REMATCH[0]}"}"
  done
  if [[ "$literal" -eq 1 && $count -gt 0 ]]; then
    message_source="flag"
  else
    : > "$tmp"
  fi
fi

if [[ -z "$message_source" ]] && [[ "$segment" =~ (-F|--file)[[:space:]]*=?[[:space:]]*([^[:space:]\"\']+) ]]; then
  file="${BASH_REMATCH[2]}"
  if [[ "$file" == "-" ]]; then
    read_heredoc_body "$segment" && message_source="heredoc"
  else
    [[ "$file" == /* ]] || file="${cwd:-$PWD}/$file"
    [[ -f "$file" ]] || block "commit message file is not readable before the command runs: $file. Pass the message with -m or a heredoc."
    cp "$file" "$tmp"
    message_source="file"
  fi
fi

if [[ -z "$message_source" ]] && read_heredoc_body "$segment"; then
  message_source="heredoc"
fi

[[ -n "$message_source" ]] || block "could not find the commit message in the command. Pass it with -m \"...\" or -m \"\$(cat <<'EOF' ... EOF)\" so it can be validated against agents/rules/git.md."

if ! DOTAGENTS_REPO_DIR="${cwd:-$PWD}" "$here/check.sh" "$tmp" 2> "$tmp.err"; then
  block "$(cat "$tmp.err")"
fi
exit 0
