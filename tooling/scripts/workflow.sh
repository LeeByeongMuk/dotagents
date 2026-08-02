#!/usr/bin/env bash
set -euo pipefail

SOURCE_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE_PATH" ]]; do
  SOURCE_DIR="$(cd "$(dirname "$SOURCE_PATH")" && pwd -P)"
  SOURCE_LINK="$(readlink "$SOURCE_PATH")"
  if [[ "$SOURCE_LINK" == /* ]]; then
    SOURCE_PATH="$SOURCE_LINK"
  else
    SOURCE_PATH="$SOURCE_DIR/$SOURCE_LINK"
  fi
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE_PATH")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
CONTRACT_FILE="${DOTAGENTS_WORKFLOW_FILE:-$REPO_ROOT/agents/workflows/product-development/workflow.toml}"

CONTRACT_TSV=""
LOCK_DIR=""
LOCK_HELD=0
LOCK_TOKEN=""
LOCK_OWNER_TEMP=""
STATE_TEMP=""

lock_owned_by_self() {
  local owner_pid owner_token
  [[ -n "$LOCK_TOKEN" && -f "$LOCK_DIR/owner" && ! -L "$LOCK_DIR/owner" ]] || return 1
  [[ "$(wc -l < "$LOCK_DIR/owner" | tr -d ' ')" == "4" ]] || return 1
  IFS= read -r owner_pid < "$LOCK_DIR/owner"
  owner_token="$(sed -n '4p' "$LOCK_DIR/owner")"
  [[ "$owner_pid" == "pid=$$" && "$owner_token" == "token=$LOCK_TOKEN" ]]
}

cleanup() {
  if [[ "$LOCK_HELD" -eq 1 && -n "$LOCK_DIR" && -d "$LOCK_DIR" && ! -L "$LOCK_DIR" ]]; then
    if lock_owned_by_self; then
      unlink "$LOCK_DIR/owner" 2>/dev/null || true
      rmdir "$LOCK_DIR" 2>/dev/null || true
    fi
  fi
  [[ -n "$LOCK_OWNER_TEMP" && ( -f "$LOCK_OWNER_TEMP" || -L "$LOCK_OWNER_TEMP" ) ]] && unlink "$LOCK_OWNER_TEMP" 2>/dev/null || true
  [[ -n "$CONTRACT_TSV" && -f "$CONTRACT_TSV" ]] && unlink "$CONTRACT_TSV" 2>/dev/null || true
  [[ -n "$STATE_TEMP" && ( -f "$STATE_TEMP" || -L "$STATE_TEMP" ) ]] && unlink "$STATE_TEMP" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

usage() {
  cat <<'EOF'
Usage:
  dotagents-workflow start --project PATH --run RUN_ID --scope standard|substantial [--skip-skill-refactor]
  dotagents-workflow status --project PATH --run RUN_ID
  dotagents-workflow approve --project PATH --run RUN_ID --stage N --user-approved
  dotagents-workflow adopt --project PATH --run RUN_ID --scope standard|substantial --through N --user-approved [--skip-skill-refactor]
  dotagents-workflow verify --project PATH --run RUN_ID
EOF
}

usage_error() {
  echo "error: $*" >&2
  usage >&2
  exit 2
}

validation_error() {
  echo "error: $*" >&2
  exit 3
}

parse_contract() {
  [[ -f "$CONTRACT_FILE" && ! -L "$CONTRACT_FILE" ]] || validation_error "workflow contract is missing or unsafe: $CONTRACT_FILE"
  CONTRACT_TSV="$(mktemp "${TMPDIR:-/tmp}/dotagents-workflow-contract.XXXXXX")"
  if ! awk '
    function fail(message) {
      print "contract error: " message > "/dev/stderr"
      failed = 1
      exit 1
    }
    function value_after_equals(line, position) {
      position = index(line, " = ")
      if (position == 0) fail("expected space-equals-space separator")
      return substr(line, position + 3)
    }
    function key_before_equals(line, position) {
      position = index(line, " = ")
      if (position == 0) fail("expected space-equals-space separator")
      return substr(line, 1, position - 1)
    }
    function quoted(value, inner) {
      if (value !~ /^"[^"]*"$/) fail("expected a quoted string")
      inner = substr(value, 2, length(value) - 2)
      if (inner == "" || inner ~ /[\t\r\n]/) fail("empty or unsafe string")
      return inner
    }
    function finish_stage() {
      if (!in_stage) return
      if (field != 8) fail("stage " stage_count " has " field " fields; expected 8")
      if (number != stage_count) fail("stage numbers must be contiguous")
      if (predecessor != number - 1) fail("invalid predecessor for stage " number)
      if (number == 10 && optional != "true") fail("stage 10 must be optional")
      if (number != 10 && optional != "false") fail("only stage 10 may be optional")
      if (requires_approval != "true") fail("every version 1 stage requires approval")
      if (seen_id[id]++) fail("duplicate stage id: " id)
      if (seen_artifact[artifact]++) fail("duplicate artifact basename: " artifact)
      print number, id, title_ko, title_en, artifact, optional
    }
    BEGIN {
      OFS = "\t"
      top = 0
      stage_count = 0
      in_stage = 0
      failed = 0
    }
    /^[[:space:]]*$/ || /^[[:space:]]*#/ { next }
    $0 == "[[stages]]" {
      finish_stage()
      in_stage = 1
      stage_count++
      field = 0
      next
    }
    !in_stage {
      top++
      key = key_before_equals($0)
      value = value_after_equals($0)
      if (top == 1 && (key != "schema_version" || value != "1")) fail("unsupported schema_version")
      if (top == 2 && (key != "id" || quoted(value) != "product-development")) fail("unexpected workflow id")
      if (top == 3 && (key != "state_version" || value != "1")) fail("unsupported state_version")
      if (top > 3) fail("unknown top-level key")
      next
    }
    in_stage {
      field++
      key = key_before_equals($0)
      value = value_after_equals($0)
      if (field == 1) {
        if (key != "number" || value !~ /^[0-9]+$/) fail("invalid stage number")
        number = value + 0
      } else if (field == 2) {
        if (key != "id") fail("stage field 2 must be id")
        id = quoted(value)
        if (id !~ /^[a-z0-9]+(-[a-z0-9]+)*$/) fail("invalid stage id")
      } else if (field == 3) {
        if (key != "title_ko") fail("stage field 3 must be title_ko")
        title_ko = quoted(value)
      } else if (field == 4) {
        if (key != "title_en") fail("stage field 4 must be title_en")
        title_en = quoted(value)
      } else if (field == 5) {
        if (key != "artifact") fail("stage field 5 must be artifact")
        artifact = quoted(value)
        if (artifact !~ /^[0-9][0-9]-[a-z0-9]+(-[a-z0-9]+)*$/) fail("invalid artifact basename")
      } else if (field == 6) {
        if (key != "optional" || value !~ /^(true|false)$/) fail("invalid optional flag")
        optional = value
      } else if (field == 7) {
        if (key != "predecessor" || value !~ /^[0-9]+$/) fail("invalid predecessor")
        predecessor = value + 0
      } else if (field == 8) {
        if (key != "requires_approval" || value !~ /^(true|false)$/) fail("invalid requires_approval flag")
        requires_approval = value
      } else {
        fail("too many fields in stage " stage_count)
      }
    }
    END {
      if (!failed) {
        finish_stage()
        if (top != 3) fail("expected exactly three top-level keys")
        if (stage_count != 10) fail("expected exactly ten stages")
      }
    }
  ' "$CONTRACT_FILE" > "$CONTRACT_TSV"; then
    validation_error "workflow contract validation failed"
  fi
  [[ "$(wc -l < "$CONTRACT_TSV" | tr -d ' ')" == "10" ]] || validation_error "workflow contract did not produce ten stages"
}

stage_field() {
  local stage_number="$1"
  local field_number="$2"
  awk -F '\t' -v stage="$stage_number" -v field="$field_number" '$1 == stage { print $field; found=1; exit } END { if (!found) exit 1 }' "$CONTRACT_TSV"
}

canonical_project() {
  local requested="$1"
  [[ -d "$requested" ]] || usage_error "project directory does not exist: $requested"
  (cd "$requested" && pwd -P)
}

validate_project_root() {
  local git_top
  if git -C "$PROJECT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
    git_top="$(git -C "$PROJECT_DIR" rev-parse --show-toplevel)"
    git_top="$(cd "$git_top" && pwd -P)"
    [[ "$git_top" == "$PROJECT_DIR" ]] || validation_error "--project must be the Git worktree root: $git_top"
  fi
}

validate_run_id() {
  [[ "$RUN_ID" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || usage_error "run ID must contain lowercase letters, digits, and single hyphens"
}

set_paths() {
  STATE_ROOT="$PROJECT_DIR/.dotagents/runs"
  RUN_DIR="$STATE_ROOT/$RUN_ID"
  STATE_FILE="$RUN_DIR/state"
  ARTIFACT_ROOT="$PROJECT_DIR/docs/workflows"
  ARTIFACT_DIR="$ARTIFACT_ROOT/$RUN_ID"
  LOCK_DIR="$STATE_ROOT/.$RUN_ID.lock"
}

reject_symlink_path() {
  local path
  for path in "$PROJECT_DIR/.dotagents" "$STATE_ROOT" "$RUN_DIR" "$PROJECT_DIR/docs" "$ARTIFACT_ROOT" "$ARTIFACT_DIR"; do
    [[ ! -L "$path" ]] || validation_error "symlinked state or artifact path is not allowed: $path"
  done
}

path_mtime() {
  if stat -f '%m' "$1" >/dev/null 2>&1; then
    stat -f '%m' "$1"
  else
    stat -c '%Y' "$1"
  fi
}

process_started_at() {
  ps -p "$1" -o lstart= 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true
}

remove_stale_lock() {
  local entry stale_dir
  [[ -d "$LOCK_DIR" && ! -L "$LOCK_DIR" ]] || return 0
  for entry in "$LOCK_DIR"/* "$LOCK_DIR"/.[!.]* "$LOCK_DIR"/..?*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    case "$(basename "$entry")" in
      owner|.owner.*) ;;
      *) validation_error "stale lock contains an unknown entry: $entry" ;;
    esac
  done
  stale_dir="$STATE_ROOT/.$RUN_ID.stale.$$.$RANDOM"
  [[ ! -e "$stale_dir" && ! -L "$stale_dir" ]] || validation_error "stale lock quarantine already exists: $stale_dir"
  mv "$LOCK_DIR" "$stale_dir" 2>/dev/null || validation_error "cannot quarantine stale lock: $LOCK_DIR"
  for entry in "$stale_dir"/* "$stale_dir"/.[!.]* "$stale_dir"/..?*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    unlink "$entry" 2>/dev/null || validation_error "cannot reclaim stale lock entry: $entry"
  done
  rmdir "$stale_dir" 2>/dev/null || validation_error "cannot reclaim stale lock quarantine: $stale_dir"
}

lock_is_stale() {
  local now lock_time age owner_line_count owner_pid owner_created owner_started owner_token current_started
  now="$(date +%s)"
  lock_time="$(path_mtime "$LOCK_DIR" 2>/dev/null || echo "$now")"
  age=$((now - lock_time))

  if [[ ! -f "$LOCK_DIR/owner" || -L "$LOCK_DIR/owner" ]]; then
    [[ "$age" -gt 5 ]]
    return
  fi

  owner_line_count="$(wc -l < "$LOCK_DIR/owner" | tr -d ' ')"
  if [[ "$owner_line_count" != "4" ]]; then
    [[ "$age" -gt 5 ]]
    return
  fi

  IFS= read -r owner_pid < "$LOCK_DIR/owner"
  owner_created="$(sed -n '2p' "$LOCK_DIR/owner")"
  owner_started="$(sed -n '3p' "$LOCK_DIR/owner")"
  owner_token="$(sed -n '4p' "$LOCK_DIR/owner")"
  owner_pid="${owner_pid#pid=}"
  owner_created="${owner_created#created_at=}"
  owner_started="${owner_started#process_started=}"
  owner_token="${owner_token#token=}"

  [[ "$owner_pid" =~ ^[0-9]+$ && "$owner_created" =~ ^[0-9]+$ && -n "$owner_started" && "$owner_token" =~ ^[A-Za-z0-9]+$ ]] || {
    [[ "$age" -gt 5 ]]
    return
  }
  kill -0 "$owner_pid" 2>/dev/null || return 0
  if [[ "$owner_started" != "unavailable" ]]; then
    current_started="$(process_started_at "$owner_pid")"
    [[ -n "$current_started" && "$current_started" == "$owner_started" ]] || return 0
  fi
  return 1
}

check_existing_lock() {
  [[ ! -e "$LOCK_DIR" && ! -L "$LOCK_DIR" ]] && return 0
  [[ -d "$LOCK_DIR" && ! -L "$LOCK_DIR" ]] || validation_error "unsafe workflow lock path: $LOCK_DIR"
  if lock_is_stale; then
    remove_stale_lock
  else
    validation_error "workflow run is locked by another active command: $RUN_ID"
  fi
}

acquire_lock() {
  local owner_temp started now
  mkdir -p "$STATE_ROOT"
  now="$(date +%s)"
  started="$(process_started_at "$$")"
  [[ -n "$started" ]] || started="unavailable"
  umask 077
  owner_temp="$(mktemp "$STATE_ROOT/.$RUN_ID.owner.XXXXXX")" || validation_error "could not create workflow lock owner"
  LOCK_OWNER_TEMP="$owner_temp"
  LOCK_TOKEN="${owner_temp##*.owner.}"
  {
    printf 'pid=%s\n' "$$"
    printf 'created_at=%s\n' "$now"
    printf 'process_started=%s\n' "$started"
    printf 'token=%s\n' "$LOCK_TOKEN"
  } > "$owner_temp"
  check_existing_lock
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    check_existing_lock
    mkdir "$LOCK_DIR" 2>/dev/null || validation_error "could not acquire workflow lock: $RUN_ID"
  fi
  LOCK_HELD=1
  ln "$owner_temp" "$LOCK_DIR/owner" 2>/dev/null || validation_error "workflow lock ownership changed during acquisition: $RUN_ID"
  unlink "$owner_temp"
  LOCK_OWNER_TEMP=""
  lock_owned_by_self || validation_error "workflow lock ownership could not be verified: $RUN_ID"
}

release_lock() {
  [[ "$LOCK_HELD" -eq 1 ]] || return 0
  lock_owned_by_self || validation_error "workflow lock ownership was lost before release: $RUN_ID"
  unlink "$LOCK_DIR/owner"
  rmdir "$LOCK_DIR"
  LOCK_HELD=0
  LOCK_TOKEN=""
}

add_local_git_exclude() {
  local exclude_path exclude_dir
  git -C "$PROJECT_DIR" rev-parse --show-toplevel >/dev/null 2>&1 || return 0
  exclude_path="$(git -C "$PROJECT_DIR" rev-parse --git-path info/exclude)"
  [[ "$exclude_path" == /* ]] || exclude_path="$PROJECT_DIR/$exclude_path"
  exclude_dir="$(dirname "$exclude_path")"
  mkdir -p "$exclude_dir"
  if [[ ! -f "$exclude_path" ]] || ! grep -Fqx '/.dotagents/runs/' "$exclude_path"; then
    {
      printf '\n# dotagents local workflow state\n'
      printf '/.dotagents/runs/\n'
    } >> "$exclude_path"
  fi
}

STATE_KEYS=(
  state_version run_id scope current_stage approved_through status optional_skill_refactor
  approval_01_at approval_02_at approval_03_at approval_04_at approval_05_at
  approval_06_at approval_07_at approval_08_at approval_09_at approval_10_at
)
for state_key_stage in 01 02 03 04 05 06 07 08 09 10; do
  STATE_KEYS+=("artifact_${state_key_stage}_ko_sha256" "artifact_${state_key_stage}_en_sha256")
done

STATE_APPROVALS=("-" "-" "-" "-" "-" "-" "-" "-" "-" "-")
STATE_HASHES_KO=("-" "-" "-" "-" "-" "-" "-" "-" "-" "-")
STATE_HASHES_EN=("-" "-" "-" "-" "-" "-" "-" "-" "-" "-")

load_state() {
  local line key value expected count index approval_value hash_value hash_position timestamp_pattern hash_pattern
  [[ -f "$STATE_FILE" && ! -L "$STATE_FILE" ]] || validation_error "workflow state is missing or unsafe: $STATE_FILE"
  count=0
  STATE_APPROVALS=("-" "-" "-" "-" "-" "-" "-" "-" "-" "-")
  STATE_HASHES_KO=("-" "-" "-" "-" "-" "-" "-" "-" "-" "-")
  STATE_HASHES_EN=("-" "-" "-" "-" "-" "-" "-" "-" "-" "-")
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *=* ]] || validation_error "invalid state line $((count + 1))"
    [[ "$count" -lt "${#STATE_KEYS[@]}" ]] || validation_error "state has unexpected extra keys"
    key="${line%%=*}"
    value="${line#*=}"
    expected="${STATE_KEYS[$count]}"
    [[ "$key" == "$expected" ]] || validation_error "state key $((count + 1)) must be $expected"
    case "$key" in
      state_version) STATE_VERSION="$value" ;;
      run_id) STATE_RUN_ID="$value" ;;
      scope) STATE_SCOPE="$value" ;;
      current_stage) STATE_CURRENT_STAGE="$value" ;;
      approved_through) STATE_APPROVED_THROUGH="$value" ;;
      status) STATE_STATUS="$value" ;;
      optional_skill_refactor) STATE_OPTIONAL_SKILL_REFACTOR="$value" ;;
      approval_*_at)
        index=$((count - 7))
        STATE_APPROVALS[$index]="$value"
        ;;
      artifact_*_sha256)
        hash_position=$((count - 17))
        index=$((hash_position / 2))
        if ((hash_position % 2 == 0)); then
          STATE_HASHES_KO[$index]="$value"
        else
          STATE_HASHES_EN[$index]="$value"
        fi
        ;;
    esac
    count=$((count + 1))
  done < "$STATE_FILE"

  [[ "$count" -eq "${#STATE_KEYS[@]}" ]] || validation_error "state must contain exactly ${#STATE_KEYS[@]} keys"
  [[ "$STATE_VERSION" == "1" ]] || validation_error "unsupported state_version; update dotagents before resuming"
  [[ "$STATE_RUN_ID" == "$RUN_ID" ]] || validation_error "state run_id does not match requested run"
  [[ "$STATE_SCOPE" == "standard" || "$STATE_SCOPE" == "substantial" ]] || validation_error "invalid state scope"
  [[ "$STATE_CURRENT_STAGE" =~ ^([1-9]|10)$ ]] || validation_error "invalid current_stage"
  [[ "$STATE_APPROVED_THROUGH" =~ ^([0-9]|10)$ ]] || validation_error "invalid approved_through"
  [[ "$STATE_STATUS" == "active" || "$STATE_STATUS" == "completed" ]] || validation_error "invalid state status"
  [[ "$STATE_OPTIONAL_SKILL_REFACTOR" == "yes" || "$STATE_OPTIONAL_SKILL_REFACTOR" == "no" ]] || validation_error "invalid optional_skill_refactor"

  timestamp_pattern='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
  hash_pattern='^[0-9a-f]{64}$'
  for ((index = 0; index < 10; index++)); do
    approval_value="${STATE_APPROVALS[$index]}"
    if [[ "$index" -lt "$STATE_APPROVED_THROUGH" ]]; then
      [[ "$approval_value" =~ $timestamp_pattern ]] || validation_error "approval_$(printf '%02d' $((index + 1)))_at is missing or invalid"
    else
      [[ "$approval_value" == "-" ]] || validation_error "approval timestamps must be continuous"
    fi
    for hash_value in "${STATE_HASHES_KO[$index]}" "${STATE_HASHES_EN[$index]}"; do
      if [[ "$index" -lt "$STATE_APPROVED_THROUGH" ]]; then
        [[ "$hash_value" =~ $hash_pattern ]] || validation_error "approved artifact hashes are missing or invalid for stage $((index + 1))"
      else
        [[ "$hash_value" == "-" ]] || validation_error "artifact hashes must be continuous with approvals"
      fi
    done
  done

  if [[ "$STATE_STATUS" == "active" ]]; then
    [[ "$STATE_CURRENT_STAGE" -eq $((STATE_APPROVED_THROUGH + 1)) ]] || validation_error "active state transition invariant failed"
    [[ "$STATE_APPROVED_THROUGH" -le 9 ]] || validation_error "active state cannot have all stages approved"
    [[ "$STATE_OPTIONAL_SKILL_REFACTOR" == "yes" || "$STATE_APPROVED_THROUGH" -lt 9 ]] || validation_error "stage 10 is skipped, so approval through 9 must be completed"
  elif [[ "$STATE_OPTIONAL_SKILL_REFACTOR" == "yes" ]]; then
    [[ "$STATE_CURRENT_STAGE" -eq 10 && "$STATE_APPROVED_THROUGH" -eq 10 ]] || validation_error "completed state with stage 10 enabled is inconsistent"
  else
    [[ "$STATE_CURRENT_STAGE" -eq 10 && "$STATE_APPROVED_THROUGH" -eq 9 ]] || validation_error "completed state with stage 10 skipped is inconsistent"
  fi
  validate_approved_artifacts
}

write_state() {
  local target="$1"
  local index
  umask 077
  STATE_TEMP="$(mktemp "$RUN_DIR/.state.tmp.XXXXXX")" || validation_error "could not create workflow state temporary file"
  {
    printf 'state_version=1\n'
    printf 'run_id=%s\n' "$RUN_ID"
    printf 'scope=%s\n' "$STATE_SCOPE"
    printf 'current_stage=%s\n' "$STATE_CURRENT_STAGE"
    printf 'approved_through=%s\n' "$STATE_APPROVED_THROUGH"
    printf 'status=%s\n' "$STATE_STATUS"
    printf 'optional_skill_refactor=%s\n' "$STATE_OPTIONAL_SKILL_REFACTOR"
    for ((index = 0; index < 10; index++)); do
      printf 'approval_%02d_at=%s\n' "$((index + 1))" "${STATE_APPROVALS[$index]}"
    done
    for ((index = 0; index < 10; index++)); do
      printf 'artifact_%02d_ko_sha256=%s\n' "$((index + 1))" "${STATE_HASHES_KO[$index]}"
      printf 'artifact_%02d_en_sha256=%s\n' "$((index + 1))" "${STATE_HASHES_EN[$index]}"
    done
  } > "$STATE_TEMP"
  lock_owned_by_self || validation_error "workflow lock ownership was lost before state update: $RUN_ID"
  mv "$STATE_TEMP" "$target"
  STATE_TEMP=""
}

artifact_is_safe() {
  local path="$1"
  [[ -f "$path" && -s "$path" && ! -L "$path" && "$(dirname "$path")" == "$ARTIFACT_DIR" ]]
}

validate_artifact_pair() {
  local stage_number="$1"
  local artifact_base korean english
  artifact_base="$(stage_field "$stage_number" 5)" || validation_error "unknown stage: $stage_number"
  korean="$ARTIFACT_DIR/$artifact_base.md"
  english="$ARTIFACT_DIR/$artifact_base.en.md"
  artifact_is_safe "$korean" || validation_error "missing, empty, or unsafe artifact: $korean"
  artifact_is_safe "$english" || validation_error "missing, empty, or unsafe artifact: $english"
}

file_sha256() {
  local path="$1"
  local digest
  if command -v shasum >/dev/null 2>&1; then
    digest="$(shasum -a 256 "$path" 2>/dev/null | awk '{ print $1 }')" || validation_error "could not hash workflow artifact: $path"
  elif command -v sha256sum >/dev/null 2>&1; then
    digest="$(sha256sum "$path" 2>/dev/null | awk '{ print $1 }')" || validation_error "could not hash workflow artifact: $path"
  else
    validation_error "SHA-256 tool is required: install shasum or sha256sum"
  fi
  [[ "$digest" =~ ^[0-9a-f]{64}$ ]] || validation_error "SHA-256 tool returned an invalid digest for: $path"
  printf '%s\n' "$digest"
}

record_artifact_hashes() {
  local stage_number="$1"
  local index artifact_base
  index=$((stage_number - 1))
  artifact_base="$(stage_field "$stage_number" 5)" || validation_error "unknown stage: $stage_number"
  STATE_HASHES_KO[$index]="$(file_sha256 "$ARTIFACT_DIR/$artifact_base.md")"
  STATE_HASHES_EN[$index]="$(file_sha256 "$ARTIFACT_DIR/$artifact_base.en.md")"
}

validate_approved_artifacts() {
  local stage_number index artifact_base actual_ko actual_en
  for ((stage_number = 1; stage_number <= STATE_APPROVED_THROUGH; stage_number++)); do
    validate_artifact_pair "$stage_number"
    index=$((stage_number - 1))
    artifact_base="$(stage_field "$stage_number" 5)" || validation_error "unknown stage: $stage_number"
    actual_ko="$(file_sha256 "$ARTIFACT_DIR/$artifact_base.md")"
    actual_en="$(file_sha256 "$ARTIFACT_DIR/$artifact_base.en.md")"
    [[ "$actual_ko" == "${STATE_HASHES_KO[$index]}" ]] || validation_error "approved Korean artifact changed after approval: $artifact_base.md"
    [[ "$actual_en" == "${STATE_HASHES_EN[$index]}" ]] || validation_error "approved English artifact changed after approval: $artifact_base.en.md"
  done
}

prepare_adopt_run_directory() {
  local entry
  if [[ -e "$RUN_DIR" || -L "$RUN_DIR" ]]; then
    [[ -d "$RUN_DIR" && ! -L "$RUN_DIR" ]] || validation_error "run state path is unsafe: $RUN_ID"
    for entry in "$RUN_DIR"/* "$RUN_DIR"/.[!.]* "$RUN_DIR"/..?*; do
      [[ -e "$entry" || -L "$entry" ]] || continue
      validation_error "lost-state adoption requires an empty run state directory: $RUN_DIR"
    done
  else
    mkdir -p "$RUN_DIR"
  fi
}

print_status() {
  local number id title_ko title_en artifact optional marker
  echo "run: $RUN_ID"
  echo "scope: $STATE_SCOPE"
  echo "status: $STATE_STATUS"
  echo "current_stage: $STATE_CURRENT_STAGE"
  echo "approved_through: $STATE_APPROVED_THROUGH"
  echo "artifacts: $ARTIFACT_DIR"
  echo "stages:"
  while IFS=$'\t' read -r number id title_ko title_en artifact optional; do
    if [[ "$number" -le "$STATE_APPROVED_THROUGH" ]]; then
      marker="approved"
    elif [[ "$number" -eq 10 && "$STATE_OPTIONAL_SKILL_REFACTOR" == "no" ]]; then
      marker="skipped"
    elif [[ "$STATE_STATUS" == "active" && "$number" -eq "$STATE_CURRENT_STAGE" ]]; then
      marker="current"
    else
      marker="pending"
    fi
    printf '  %s. [%s] %s / %s -> %s.md + %s.en.md\n' "$number" "$marker" "$title_ko" "$title_en" "$artifact" "$artifact"
  done < "$CONTRACT_TSV"
}

COMMAND="${1:-}"
[[ -n "$COMMAND" ]] || usage_error "a command is required"
case "$COMMAND" in
  start|status|approve|adopt|verify) shift ;;
  -h|--help|help) usage; exit 0 ;;
  *) usage_error "unknown command: $COMMAND" ;;
esac

PROJECT_ARG=""
RUN_ID=""
SCOPE_ARG=""
STAGE_ARG=""
THROUGH_ARG=""
SKIP_SKILL_REFACTOR=0
USER_APPROVED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      [[ $# -ge 2 && -z "$PROJECT_ARG" ]] || usage_error "--project requires one path"
      PROJECT_ARG="$2"
      shift
      ;;
    --run)
      [[ $# -ge 2 && -z "$RUN_ID" ]] || usage_error "--run requires one ID"
      RUN_ID="$2"
      shift
      ;;
    --scope)
      [[ $# -ge 2 && -z "$SCOPE_ARG" ]] || usage_error "--scope requires one value"
      SCOPE_ARG="$2"
      shift
      ;;
    --stage)
      [[ $# -ge 2 && -z "$STAGE_ARG" ]] || usage_error "--stage requires one number"
      STAGE_ARG="$2"
      shift
      ;;
    --through)
      [[ $# -ge 2 && -z "$THROUGH_ARG" ]] || usage_error "--through requires one number"
      THROUGH_ARG="$2"
      shift
      ;;
    --skip-skill-refactor) SKIP_SKILL_REFACTOR=1 ;;
    --user-approved) USER_APPROVED=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage_error "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$PROJECT_ARG" ]] || usage_error "--project is required"
[[ -n "$RUN_ID" ]] || usage_error "--run is required"
PROJECT_DIR="$(canonical_project "$PROJECT_ARG")"
validate_project_root
validate_run_id
set_paths
reject_symlink_path
parse_contract

case "$COMMAND" in
  start)
    [[ "$SCOPE_ARG" == "standard" || "$SCOPE_ARG" == "substantial" ]] || usage_error "start requires --scope standard or substantial"
    [[ -z "$STAGE_ARG" && -z "$THROUGH_ARG" && "$USER_APPROVED" -eq 0 ]] || usage_error "invalid option for start"
    mkdir -p "$STATE_ROOT"
    acquire_lock
    [[ ! -e "$RUN_DIR" && ! -L "$RUN_DIR" ]] || validation_error "run state already exists: $RUN_ID"
    [[ ! -e "$ARTIFACT_DIR" && ! -L "$ARTIFACT_DIR" ]] || validation_error "artifact directory already exists; use adopt after reviewing it"
    add_local_git_exclude
    mkdir -p "$RUN_DIR" "$ARTIFACT_DIR"
    STATE_SCOPE="$SCOPE_ARG"
    STATE_CURRENT_STAGE=1
    STATE_APPROVED_THROUGH=0
    STATE_STATUS="active"
    if [[ "$SKIP_SKILL_REFACTOR" -eq 1 ]]; then
      STATE_OPTIONAL_SKILL_REFACTOR="no"
    else
      STATE_OPTIONAL_SKILL_REFACTOR="yes"
    fi
    STATE_APPROVALS=("-" "-" "-" "-" "-" "-" "-" "-" "-" "-")
    STATE_HASHES_KO=("-" "-" "-" "-" "-" "-" "-" "-" "-" "-")
    STATE_HASHES_EN=("-" "-" "-" "-" "-" "-" "-" "-" "-" "-")
    write_state "$STATE_FILE"
    print_status
    ;;
  status)
    [[ -z "$SCOPE_ARG" && -z "$STAGE_ARG" && -z "$THROUGH_ARG" && "$SKIP_SKILL_REFACTOR" -eq 0 && "$USER_APPROVED" -eq 0 ]] || usage_error "invalid option for status"
    check_existing_lock
    load_state
    print_status
    ;;
  approve)
    [[ -z "$SCOPE_ARG" && -z "$THROUGH_ARG" && "$SKIP_SKILL_REFACTOR" -eq 0 ]] || usage_error "invalid option for approve"
    [[ "$STAGE_ARG" =~ ^([1-9]|10)$ ]] || usage_error "approve requires --stage 1 through 10"
    [[ "$USER_APPROVED" -eq 1 ]] || usage_error "approve requires --user-approved after explicit user confirmation"
    acquire_lock
    load_state
    [[ "$STATE_STATUS" == "active" ]] || validation_error "completed runs cannot be approved again"
    [[ "$STAGE_ARG" -eq "$STATE_CURRENT_STAGE" ]] || validation_error "only current stage $STATE_CURRENT_STAGE may be approved"
    validate_artifact_pair "$STAGE_ARG"
    record_artifact_hashes "$STAGE_ARG"
    STATE_APPROVALS[$((STAGE_ARG - 1))]="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    STATE_APPROVED_THROUGH="$STAGE_ARG"
    if [[ "$STAGE_ARG" -eq 10 || ( "$STAGE_ARG" -eq 9 && "$STATE_OPTIONAL_SKILL_REFACTOR" == "no" ) ]]; then
      STATE_CURRENT_STAGE=10
      STATE_STATUS="completed"
    else
      STATE_CURRENT_STAGE=$((STAGE_ARG + 1))
      STATE_STATUS="active"
    fi
    write_state "$STATE_FILE"
    echo "approved_stage: $STAGE_ARG"
    echo "status: $STATE_STATUS"
    echo "current_stage: $STATE_CURRENT_STAGE"
    ;;
  adopt)
    [[ -z "$STAGE_ARG" ]] || usage_error "invalid option for adopt"
    [[ "$SCOPE_ARG" == "standard" || "$SCOPE_ARG" == "substantial" ]] || usage_error "adopt requires --scope standard or substantial"
    [[ "$THROUGH_ARG" =~ ^([1-9]|10)$ ]] || usage_error "adopt requires --through 1 through 10"
    [[ "$USER_APPROVED" -eq 1 ]] || usage_error "adopt requires --user-approved after explicit user confirmation"
    [[ ! ( "$THROUGH_ARG" -eq 10 && "$SKIP_SKILL_REFACTOR" -eq 1 ) ]] || usage_error "cannot adopt stage 10 when skill refactoring is skipped"
    [[ -d "$ARTIFACT_DIR" && ! -L "$ARTIFACT_DIR" ]] || validation_error "canonical artifact directory is required before adopt: $ARTIFACT_DIR"
    mkdir -p "$STATE_ROOT"
    acquire_lock
    prepare_adopt_run_directory
    for ((stage_number = 1; stage_number <= THROUGH_ARG; stage_number++)); do
      validate_artifact_pair "$stage_number"
    done
    add_local_git_exclude
    mkdir -p "$RUN_DIR"
    STATE_SCOPE="$SCOPE_ARG"
    STATE_APPROVED_THROUGH="$THROUGH_ARG"
    if [[ "$SKIP_SKILL_REFACTOR" -eq 1 ]]; then
      STATE_OPTIONAL_SKILL_REFACTOR="no"
    else
      STATE_OPTIONAL_SKILL_REFACTOR="yes"
    fi
    if [[ "$THROUGH_ARG" -eq 10 ]]; then
      STATE_CURRENT_STAGE=10
      STATE_STATUS="completed"
    elif [[ "$THROUGH_ARG" -eq 9 && "$STATE_OPTIONAL_SKILL_REFACTOR" == "no" ]]; then
      STATE_CURRENT_STAGE=10
      STATE_STATUS="completed"
    else
      STATE_CURRENT_STAGE=$((THROUGH_ARG + 1))
      STATE_STATUS="active"
    fi
    adopted_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    STATE_APPROVALS=("-" "-" "-" "-" "-" "-" "-" "-" "-" "-")
    STATE_HASHES_KO=("-" "-" "-" "-" "-" "-" "-" "-" "-" "-")
    STATE_HASHES_EN=("-" "-" "-" "-" "-" "-" "-" "-" "-" "-")
    for ((stage_number = 0; stage_number < THROUGH_ARG; stage_number++)); do
      STATE_APPROVALS[$stage_number]="$adopted_at"
      record_artifact_hashes "$((stage_number + 1))"
    done
    write_state "$STATE_FILE"
    print_status
    ;;
  verify)
    [[ -z "$SCOPE_ARG" && -z "$STAGE_ARG" && -z "$THROUGH_ARG" && "$SKIP_SKILL_REFACTOR" -eq 0 && "$USER_APPROVED" -eq 0 ]] || usage_error "invalid option for verify"
    check_existing_lock
    load_state
    [[ "$STATE_STATUS" == "completed" ]] || validation_error "workflow is not completed; current stage is $STATE_CURRENT_STAGE"
    for ((stage_number = 1; stage_number <= STATE_APPROVED_THROUGH; stage_number++)); do
      validate_artifact_pair "$stage_number"
    done
    echo "verified: true"
    echo "run: $RUN_ID"
    echo "approved_through: $STATE_APPROVED_THROUGH"
    echo "artifacts: $ARTIFACT_DIR"
    ;;
esac

release_lock
