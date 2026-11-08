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

# A heredoc body is data, not command text. Blank those lines out, preserving
# offsets, so a `git commit` or an -m flag written inside a heredoc body is not
# mistaken for the command being run.
code_only="$(printf '%s\n' "$command" | awk '
  {
    if (in_body) {
      probe = $0
      sub(/^[[:space:]]+/, "", probe)
      sub(/[[:space:]]+$/, "", probe)
      if (probe == marker) { in_body = 0 }
      gsub(/./, " ")
      print
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

block() {
  echo "$*" >&2
  exit 2
}

# Tokenize literal shell words without running the command. Preserve both the
# decoded word and its source offsets; quote removal alone would split -C and
# -F paths containing spaces. Expansions stay marked as nonliteral.
words=() ends=() literals=() operators=()
word="" quote="" active=0 literal=1 i=0
push_word() {
  [[ "$active" -eq 1 ]] || return 0
  words+=("$word") ends+=("$i")
  literals+=("$literal") operators+=(0)
  word="" active=0 literal=1
}
# Keep substitutions opaque even when unquoted: their spaces and operators are
# part of one nonliteral argument, never commands for this hook to execute.
skip_substitution() {
  local delimiter="$1" depth=1 inner_quote="" ch next
  i=$((i + ${#delimiter}))
  while [[ "$i" -lt "${#code_only}" ]]; do
    ch="${code_only:$i:1}" next="${code_only:$((i + 1)):1}"
    if [[ "$inner_quote" == "'" ]]; then
      [[ "$ch" != "'" ]] || inner_quote=""
    elif [[ "$ch" == '\' ]]; then
      i=$((i + 1))
    elif [[ "$ch" == '$' && "$next" == '(' ]]; then
      skip_substitution '$('
    elif [[ "$ch" == '`' ]]; then
      if [[ "$delimiter" == '`' ]]; then return 0; else skip_substitution '`'; fi
    elif [[ "$inner_quote" == '"' ]]; then
      [[ "$ch" != '"' ]] || inner_quote=""
    elif [[ "$ch" == "'" || "$ch" == '"' ]]; then
      inner_quote="$ch"
    elif [[ "$delimiter" == '$(' ]]; then
      case "$ch" in
        '(') depth=$((depth + 1)) ;;
        ')') depth=$((depth - 1)); [[ "$depth" -gt 0 ]] || return 0 ;;
      esac
    fi
    i=$((i + 1))
  done
}
while [[ "$i" -lt "${#code_only}" ]]; do
  # Heredoc bodies are blanked above to retain source offsets. Skip each run
  # at once so a large file-writing command does not exhaust the hook timeout.
  if [[ -z "$quote" && "${code_only:$i}" =~ ^([[:blank:]]+) ]]; then
    blank_length="${#BASH_REMATCH[1]}"
    push_word
    i=$((i + blank_length))
    continue
  fi
  ch="${code_only:$i:1}"
  next="${code_only:$((i + 1)):1}"
  if [[ "$quote" == "'" ]]; then
    if [[ "$ch" == "'" ]]; then quote=""; else word+="$ch"; fi
  elif [[ "$ch" == '\' && "$quote" != "'" ]]; then
    if [[ "$quote" == '"' && "$next" != [\$\`\"\\] && "$next" != $'\n' ]]; then
      word+="$ch"
    else
      if [[ "$next" != $'\n' ]]; then
        active=1
        word+="$next"
      fi
      i=$((i + 1))
    fi
  elif [[ "$ch" == '$' && "$next" == '(' || "$ch" == '`' ]]; then
    expansion_start="$i"
    if [[ "$ch" == '$' ]]; then skip_substitution '$('; else skip_substitution '`'; fi
    active=1 literal=0
    word+="${code_only:$expansion_start:$((i - expansion_start + 1))}"
  elif [[ "$quote" == '"' ]]; then
    if [[ "$ch" == '"' ]]; then
      quote=""
    else
      [[ "$ch" != '$' && "$ch" != '`' ]] || literal=0
      word+="$ch"
    fi
  elif [[ "$ch" == "'" || "$ch" == '"' ]]; then
    active=1 quote="$ch"
  elif [[ "$ch" == [[:space:]] && "$ch" != $'\n' ]]; then
    push_word
  elif [[ "$ch" == [\;\&\|\(\)\<\>] || "$ch" == $'\n' ]]; then
    push_word
    words+=("$ch") ends+=("$((i + 1))")
    literals+=(1) operators+=(1)
  elif [[ "$ch" == '#' && "$active" -eq 0 ]]; then
    while [[ "$i" -lt "${#code_only}" && "${code_only:$i:1}" != $'\n' ]]; do i=$((i + 1)); done
    continue
  else
    active=1
    case "$ch" in '$'|'`'|'*'|'?'|'['|'~'|'{'|'}') literal=0 ;; esac
    word+="$ch"
  fi
  i=$((i + 1))
done
push_word

# Only global -C options change Git's working directory. Once we reach commit,
# -C is a different option (reuse-message) and must not change the target.
commit_index="" repo_dir="${cwd:-$PWD}" unresolved_dir=0
command_position=1 prefix="" redirect_operand=0
for ((i = 0; i < ${#words[@]}; i++)); do
  arg="${words[i]}"
  if [[ "${operators[i]}" -eq 1 ]]; then
    case "$arg" in
      ';'|'&'|'|'|'('|$'\n') command_position=1 prefix="" redirect_operand=0 ;;
      '<'|'>') redirect_operand=1 ;;
      ')') command_position=0 ;;
    esac
    continue
  fi
  if [[ "$redirect_operand" -eq 1 ]]; then redirect_operand=0; continue; fi
  [[ "$command_position" -eq 1 ]] || continue
  # Bounded command prefixes, rather than arbitrary words before "git". This
  # prevents quoted data such as printf '%s\n' 'git' 'commit' from being checked.
  [[ ! "$arg" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
  case "$prefix:$arg" in
    command:-p|command:--|exec:-c|exec:-l|exec:--|env:-i|env:--ignore-environment|env:--|sudo:-n|sudo:-E|sudo:--)
      continue ;;
    env:-u|env:--unset|sudo:-u|sudo:-g|exec:-a) i=$((i + 1)); continue ;;
    env:--unset=*) continue ;;
  esac
  case "$arg" in
    env|command|exec|sudo) prefix="$arg"; continue ;;
    if|then|elif|else|while|until|do) prefix=""; continue ;;
    '!') continue ;;
  esac
  command_position=0
  [[ "$arg" == git && "${literals[i]}" -eq 1 ]] || continue
  candidate_dir="${cwd:-$PWD}" candidate_unresolved=0
  j=$((i + 1))
  while [[ "$j" -lt "${#words[@]}" && "${operators[j]}" -eq 0 ]]; do
    arg="${words[j]}"
    case "$arg" in
      commit)
        commit_index="$j" repo_dir="$candidate_dir" unresolved_dir="$candidate_unresolved"
        break ;;
      -C)
        j=$((j + 1))
        [[ "$j" -lt "${#words[@]}" && "${operators[j]}" -eq 0 ]] || break
        dir="${words[j]}"
        [[ "${literals[j]}" -eq 1 ]] || candidate_unresolved=1 ;;
      -C?*)
        dir="${arg#-C}"
        [[ "${literals[j]}" -eq 1 ]] || candidate_unresolved=1 ;;
      -c|--git-dir|--work-tree|--namespace|--config-env)
        j=$((j + 2))
        continue ;;
      -*) j=$((j + 1)); continue ;;
      *) break ;;
    esac
    if [[ -n "$dir" ]]; then
      if [[ "$dir" == /* ]]; then candidate_dir="$dir"; else candidate_dir+="/$dir"; fi
    fi
    j=$((j + 1))
  done
  [[ -z "$commit_index" ]] || break
done
[[ -n "$commit_index" ]] || exit 0

# Everything after commit, so earlier commands and global options cannot supply
# its message. The heredoc blanks have the same offsets as the original text.
segment="${command:${ends[commit_index]}}"
commit_line="$(printf '%s\n' "${code_only:${ends[commit_index]}}" | awk '!done { if (sub(/\\$/, "")) { printf "%s ", $0 } else { print; done = 1 } }')"
commit_args="$(printf '%s' "$commit_line" | sed -E -e 's/"([^"\\]|\\.)*"//g' -e "s/'[^']*'//g")"
commit_args="${commit_args%%[;&|]*}"
if printf '%s' "$commit_args" | grep -Eq -- '(^|[[:space:]])(--no-edit|--reuse-message|--reedit-message|--fixup|--squash|-[cC])([[:space:]=]|$)'; then
  exit 0
fi
[[ "$unresolved_dir" -eq 0 ]] || block "cannot resolve git -C directory before the command runs. Use a literal directory so the repository commit policy can be checked."

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

if [[ -z "$message_source" ]]; then
  for ((i = commit_index + 1; i < ${#words[@]}; i++)); do
    [[ "${operators[i]}" -eq 0 ]] || break
    case "${words[i]}" in
      -F|--file)
        i=$((i + 1))
        [[ "$i" -lt "${#words[@]}" ]] || break
        file="${words[i]}" ;;
      -F?*) file="${words[i]#-F}" ;;
      --file=*) file="${words[i]#--file=}" ;;
      --) break ;;
      *) continue ;;
    esac
    [[ "${literals[i]}" -eq 1 ]] || block "cannot resolve commit message file before the command runs. Use a literal path, -m, or a heredoc."
    if [[ "$file" == "-" ]]; then
      read_heredoc_body "$segment" && message_source="heredoc"
    else
      [[ "$file" == /* ]] || file="$repo_dir/$file"
      [[ -f "$file" ]] || block "commit message file is not readable before the command runs: $file. Pass the message with -m or a heredoc."
      cp "$file" "$tmp"
      message_source="file"
    fi
    break
  done
fi

if [[ -z "$message_source" ]] && read_heredoc_body "$segment"; then
  message_source="heredoc"
fi

[[ -n "$message_source" ]] || block "could not find the commit message in the command. Pass it with -m \"...\" or -m \"\$(cat <<'EOF' ... EOF)\" so it can be validated against agents/rules/git.md."

if ! DOTAGENTS_REPO_DIR="$repo_dir" "$here/check.sh" "$tmp" 2> "$tmp.err"; then
  block "$(cat "$tmp.err")"
fi
exit 0
