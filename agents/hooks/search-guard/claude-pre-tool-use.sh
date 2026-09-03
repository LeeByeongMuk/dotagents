#!/usr/bin/env bash
# Claude Code PreToolUse hook (matcher: Bash). Blocks two shapes of shell read
# that make Claude Code ask for permission even in bypassPermissions mode once a
# Read deny rule (.env, *.pem, ...) is configured (Claude Code 2.1.259):
#   1. recursive searches (`rg`, `ag`, `ack`, `grep -r`) that walk a tree, and
#   2. a `cd` into another directory followed by a reader command (grep, cat,
#      head, sed, ...) given a relative path, which the permission checker
#      cannot resolve.
# The Grep and Read tools, or absolute paths, do the same work without a
# prompt. Exit 2 blocks the tool call; exit 0 allows it.
set -euo pipefail

input="$(cat)"
command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
[[ -n "$command" ]] || exit 0
[[ -n "$cwd" ]] || cwd="$PWD"

block() {
  cat >&2 <<EOF
dotagents search-guard blocked: $*
Recursive shell searches (rg, ag, ack, grep -r) walk the whole tree. When it holds a file covered by a Read deny rule (.env, *.pem, *.key, ...), Claude Code asks for permission even in bypassPermissions mode.
Use the Grep tool (pattern, path, glob, output_mode) or the Glob tool instead, or run grep/cat on named files.
EOF
  exit 2
}

block_cd() {
  cat >&2 <<EOF
dotagents search-guard blocked: $*
After a cd into another directory, Claude Code cannot resolve a relative path against the Read deny rules and asks for permission even in bypassPermissions mode.
Drop the cd prefix and pass absolute paths (the Bash tool already runs in the working directory), or use the Read and Grep tools.
EOF
  exit 2
}

# Drop heredoc bodies (data such as commit messages, not commands). Replace each
# quoted string with its content when it is a single plain word, so a quoted
# path stays visible, and with a placeholder otherwise, so a pattern such as
# "a -r b" is not read as flags. Then split into simple commands at shell
# operators.
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
stripped="$(printf '%s\n' "$no_heredoc" | awk -v q="'" '
  {
    out = ""
    s = $0
    re = "\"[^\"]*\"|" q "[^" q "]*" q
    while (match(s, re)) {
      out = out substr(s, 1, RSTART - 1)
      inner = substr(s, RSTART + 1, RLENGTH - 2)
      if (inner ~ /^[^[:space:]-][^[:space:]]*$/) out = out inner
      else out = out "__QUOTED__"
      s = substr(s, RSTART + RLENGTH)
    }
    print out s
  }
')"
simple_commands="$(printf '%s' "$stripped" | sed -E 's/(\|\||&&|;|\||\(|\)|`|\$\()/\
/g')"

cwd_real="$(cd "$cwd" 2>/dev/null && pwd -P || printf '%s' "$cwd")"
changed_dir=0
cd_target=""

# True when `cd <target>` stays in the session directory or below it, which the
# permission checker still resolves. An unresolvable target counts as leaving.
cd_stays_inside() {
  local target="$1" resolved
  [[ -n "$target" ]] || target="$HOME"
  case "$target" in
    -|*'$'*|*__QUOTED__*) return 1 ;;
    '~') target="$HOME" ;;
    '~/'*) target="$HOME/${target#'~/'}" ;;
  esac
  resolved="$(cd "$cwd" 2>/dev/null && cd "$target" 2>/dev/null && pwd -P)" || return 1
  [[ "$resolved" == "$cwd_real" || "$resolved" == "$cwd_real"/* ]]
}

# Print the first operand of a reader command that is not an absolute path.
# Skips options, the values of options that take one, and the pattern or
# script argument of grep, sed, awk, and jq.
relative_operand() {
  local cmd="$1"
  shift
  local skip_first=0 valopts="" pattern_opts=""
  case "$cmd" in
    grep|egrep|fgrep)
      skip_first=1
      pattern_opts=" -e -f --regexp --file "
      valopts=" -e -f -m -A -B -C -d --regexp --file --max-count --include --exclude --exclude-dir --directories "
      ;;
    sed)
      skip_first=1
      pattern_opts=" -e -f --expression --file "
      valopts=" -e -f --expression --file "
      ;;
    awk)
      skip_first=1
      pattern_opts=" -f "
      valopts=" -F -v -f "
      ;;
    jq)
      skip_first=1
      pattern_opts=" -f --from-file "
      valopts=" -f --from-file --indent -L --arg --argjson --slurpfile --rawfile "
      ;;
    head|tail) valopts=" -n -c " ;;
    cut) valopts=" -d -f -c -b " ;;
    sort) valopts=" -k -t -o -S -T " ;;
    uniq) valopts=" -f -s -w " ;;
    diff) valopts=" -U -C -I -x -X -S --unified --context " ;;
    od) valopts=" -N -j -t -A -w " ;;
    xxd) valopts=" -s -l -c -g " ;;
    strings) valopts=" -n -t " ;;
  esac
  local -a args=("$@")
  local n=${#args[@]} j=0 w opt after_dd=0 first_done=0
  while [[ $j -lt $n ]]; do
    w="${args[$j]}"
    if [[ $after_dd -eq 0 ]]; then
      if [[ "$w" == "--" ]]; then
        after_dd=1
        j=$((j + 1))
        continue
      fi
      if [[ "$w" == -?* ]]; then
        opt="${w%%=*}"
        if [[ "$w" != *=* && "$valopts" == *" $opt "* ]]; then
          [[ "$pattern_opts" == *" $opt "* ]] && skip_first=0
          case "$opt" in
            --arg|--argjson|--slurpfile|--rawfile) j=$((j + 3)) ;;
            *) j=$((j + 2)) ;;
          esac
        else
          [[ "$w" == *=* && "$pattern_opts" == *" $opt "* ]] && skip_first=0
          j=$((j + 1))
        fi
        continue
      fi
    fi
    if [[ $skip_first -eq 1 && $first_done -eq 0 ]]; then
      first_done=1
      j=$((j + 1))
      continue
    fi
    if [[ "$w" != /* && "$w" != "-" && "$w" != "__QUOTED__" ]]; then
      printf '%s' "$w"
      return 0
    fi
    j=$((j + 1))
  done
  return 1
}

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
  args=()
  [[ $((i + 1)) -lt ${#words[@]} ]] && args=("${words[@]:$((i + 1))}")

  case "$cmd" in
    cd|pushd)
      target=""
      [[ ${#args[@]} -gt 0 ]] && target="${args[0]}"
      if cd_stays_inside "$target"; then
        changed_dir=0
      else
        changed_dir=1
        cd_target="$target"
      fi
      ;;
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

  if [[ $changed_dir -eq 1 ]]; then
    case "$cmd" in
      grep|egrep|fgrep|cat|head|tail|sed|awk|wc|sort|uniq|cut|diff|stat|file|jq|less|more|tac|nl|od|xxd|strings)
        if operand="$(relative_operand "$cmd" ${args[@]+"${args[@]}"})"; then
          block_cd "cd ${cd_target:-\$HOME} then $cmd $operand"
        fi
        ;;
    esac
  fi
done <<< "$simple_commands"

exit 0
