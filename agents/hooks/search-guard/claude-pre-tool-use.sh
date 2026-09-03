#!/usr/bin/env bash
# Claude Code PreToolUse hook (matcher: Bash). Blocks recursive shell searches
# (`rg`, `ag`, `ack`, `grep -r`). Since Claude Code 2.1.259 such a command that
# walks a directory holding a file covered by a Read deny rule (.env, *.pem, ...)
# asks for permission even in bypassPermissions mode. The Grep tool runs the
# same search without a prompt. Exit 2 blocks the tool call; exit 0 allows it.
set -euo pipefail

input="$(cat)"
command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
[[ -n "$command" ]] || exit 0

block() {
  cat >&2 <<EOF
dotagents search-guard blocked: $*
Recursive shell searches (rg, ag, ack, grep -r) walk the whole tree. When it holds a file covered by a Read deny rule (.env, *.pem, *.key, ...), Claude Code asks for permission even in bypassPermissions mode.
Use the Grep tool (pattern, path, glob, output_mode) or the Glob tool instead, or run grep/cat on named files.
EOF
  exit 2
}

# Drop heredoc bodies (data such as commit messages, not commands), then quoted
# text so a search pattern such as "-r" or 'rg' is not read as a flag or a
# command, then split into simple commands at shell operators.
no_heredoc="$(printf '%s\n' "$command" | awk -v q="'" '
  marker != "" {
    if ($0 ~ ("^[[:space:]]*" marker "[[:space:]]*$")) marker = ""
    next
  }
  { print }
  match($0, "<<-?[[:space:]]*[" q "\"]?[A-Za-z_][A-Za-z0-9_]*[" q "\"]?") {
    marker = substr($0, RSTART, RLENGTH)
    sub(/^<<-?[[:space:]]*/, "", marker)
    gsub("[" q "\"]", "", marker)
  }
')"
stripped="$(printf '%s' "$no_heredoc" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")"
simple_commands="$(printf '%s' "$stripped" | sed -E 's/(\|\||&&|;|\||\(|\)|`|\$\()/\
/g')"

while IFS= read -r line; do
  words=()
  read -r -a words <<< "$line" || true
  [[ ${#words[@]} -gt 0 ]] || continue

  # Skip env assignments and wrappers that precede the real command.
  i=0
  while [[ $i -lt ${#words[@]} ]]; do
    w="${words[$i]}"
    prev=""
    [[ $i -gt 0 ]] && prev="${words[$((i - 1))]}"
    if [[ "$w" != -* && "$w" == *=* ]] \
      || [[ "$w" =~ ^(sudo|env|xargs|command|time|nice|nohup|exec)$ ]] \
      || [[ "$w" == -* && "$prev" =~ ^(xargs|env|nice|sudo)$ ]]; then
      i=$((i + 1))
      continue
    fi
    break
  done
  [[ $i -lt ${#words[@]} ]] || continue

  cmd="${words[$i]##*/}"
  cmd="${cmd#\\}"
  case "$cmd" in
    rg|ag|ack)
      block "$cmd"
      ;;
    grep|egrep|fgrep)
      j=$((i + 1))
      while [[ $j -lt ${#words[@]} ]]; do
        w="${words[$j]}"
        [[ "$w" == "--" ]] && break
        next="${words[$((j + 1))]:-}"
        if [[ "$w" =~ ^-[A-Za-z]*[rR] ]] \
          || [[ "$w" =~ ^--(recursive|dereference-recursive|directories=recurse)$ ]] \
          || { [[ "$w" == "-d" || "$w" == "--directories" ]] && [[ "$next" == "recurse" ]]; }; then
          block "$cmd $w"
        fi
        j=$((j + 1))
      done
      ;;
  esac
done <<< "$simple_commands"

exit 0
