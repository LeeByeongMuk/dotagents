#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
WORKFLOW="$REPO_ROOT/tooling/scripts/workflow.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-workflow-test.XXXXXX")"
trap 'rm -r "$TEST_ROOT"' EXIT

fail() { echo "test failed: $*" >&2; exit 1; }

new_project() {
  local name="$1"
  local path="$TEST_ROOT/$name"
  mkdir -p "$path"
  git -C "$path" init -q
  echo "$path"
}

assert_contains() {
  local text="$1"
  local expected="$2"
  [[ "$text" == *"$expected"* ]] || fail "expected output to contain: $expected"
}

assert_exit() {
  local expected="$1"
  shift
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  [[ "$actual" -eq "$expected" ]] || fail "expected exit $expected, got $actual: $*"
}

artifact_base() {
  case "$1" in
    1) echo "01-interview" ;;
    2) echo "02-domain" ;;
    3) echo "03-design" ;;
    4) echo "04-spec" ;;
    5) echo "05-plan" ;;
    6) echo "06-plan-review" ;;
    7) echo "07-implementation" ;;
    8) echo "08-review" ;;
    9) echo "09-architecture" ;;
    10) echo "10-skill-retro" ;;
    *) fail "unknown fixture stage: $1" ;;
  esac
}

write_artifact() {
  local project="$1"
  local run_id="$2"
  local stage="$3"
  local base
  base="$(artifact_base "$stage")"
  mkdir -p "$project/docs/workflows/$run_id"
  printf '# 단계 %s\n' "$stage" > "$project/docs/workflows/$run_id/$base.md"
}

write_artifacts_through() {
  local project="$1"
  local run_id="$2"
  local through="$3"
  local stage
  for ((stage = 1; stage <= through; stage++)); do
    write_artifact "$project" "$run_id" "$stage"
  done
}

echo "scenario 1: start exposes the audited ten-stage contract"
project_one="$(new_project start)"
start_output="$(bash "$WORKFLOW" start --project "$project_one" --run checkout-flow --scope substantial --skip-skill-refactor)"
assert_contains "$start_output" "current_stage: 1"
assert_contains "$start_output" "mode: audited"
assert_contains "$start_output" "10. [skipped]"
[[ -f "$project_one/.dotagents/runs/checkout-flow/state" ]] || fail "start did not create state"
grep -Fqx '/.dotagents/runs/' "$project_one/.git/info/exclude" || fail "local workflow state was not excluded"

echo "scenario 2: approval requires explicit user confirmation and an artifact"
assert_exit 2 bash "$WORKFLOW" approve --project "$project_one" --run checkout-flow --stage 1
assert_exit 3 bash "$WORKFLOW" approve --project "$project_one" --run checkout-flow --stage 1 --user-approved
write_artifact "$project_one" checkout-flow 1
approve_output="$(bash "$WORKFLOW" approve --project "$project_one" --run checkout-flow --stage 1 --user-approved)"
assert_contains "$approve_output" "current_stage: 2"
grep -Eq '^approval_01_at=[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$project_one/.dotagents/runs/checkout-flow/state" || fail "approval timestamp was not recorded"
grep -Eq '^artifact_01_sha256=[0-9a-f]{64}$' "$project_one/.dotagents/runs/checkout-flow/state" || fail "artifact hash was not recorded"

echo "scenario 3: normal approval rejects a symlinked artifact"
write_artifact "$project_one" checkout-flow 2
mv "$project_one/docs/workflows/checkout-flow/02-domain.md" "$project_one/docs/workflows/checkout-flow/domain-target.md"
ln -s domain-target.md "$project_one/docs/workflows/checkout-flow/02-domain.md"
assert_exit 3 bash "$WORKFLOW" approve --project "$project_one" --run checkout-flow --stage 2 --user-approved
unlink "$project_one/docs/workflows/checkout-flow/02-domain.md"
mv "$project_one/docs/workflows/checkout-flow/domain-target.md" "$project_one/docs/workflows/checkout-flow/02-domain.md"

echo "scenario 4: a run with stage 10 skipped completes at stage 9"
for stage in 2 3 4 5 6 7 8 9; do
  [[ -f "$project_one/docs/workflows/checkout-flow/$(artifact_base "$stage").md" ]] || write_artifact "$project_one" checkout-flow "$stage"
  bash "$WORKFLOW" approve --project "$project_one" --run checkout-flow --stage "$stage" --user-approved >/dev/null
done
verify_output="$(bash "$WORKFLOW" verify --project "$project_one" --run checkout-flow)"
assert_contains "$verify_output" "verified: true"
assert_contains "$verify_output" "approved_through: 9"
cp "$project_one/docs/workflows/checkout-flow/01-interview.md" "$TEST_ROOT/approved-interview.md"
printf '\nchanged after approval\n' >> "$project_one/docs/workflows/checkout-flow/01-interview.md"
assert_exit 3 bash "$WORKFLOW" verify --project "$project_one" --run checkout-flow
cp "$TEST_ROOT/approved-interview.md" "$project_one/docs/workflows/checkout-flow/01-interview.md"

echo "scenario 5: adopt resumes at N+1 and rejects an impossible terminal state"
project_two="$(new_project adopt-active)"
write_artifacts_through "$project_two" imported-plan 5
adopt_output="$(bash "$WORKFLOW" adopt --project "$project_two" --run imported-plan --scope standard --through 5 --user-approved)"
assert_contains "$adopt_output" "current_stage: 6"
assert_contains "$adopt_output" "status: active"

project_three="$(new_project adopt-skipped)"
write_artifacts_through "$project_three" imported-complete 9
adopt_complete="$(bash "$WORKFLOW" adopt --project "$project_three" --run imported-complete --scope standard --through 9 --user-approved --skip-skill-refactor)"
assert_contains "$adopt_complete" "status: completed"
assert_contains "$adopt_complete" "approved_through: 9"

project_four="$(new_project adopt-invalid)"
write_artifacts_through "$project_four" invalid-import 10
assert_exit 2 bash "$WORKFLOW" adopt --project "$project_four" --run invalid-import --scope standard --through 10 --user-approved --skip-skill-refactor

echo "scenario 6: adopt stage 10 creates a completed full run"
write_artifacts_through "$project_four" full-import 10
adopt_full="$(bash "$WORKFLOW" adopt --project "$project_four" --run full-import --scope substantial --through 10 --user-approved)"
assert_contains "$adopt_full" "status: completed"
assert_contains "$adopt_full" "approved_through: 10"

echo "scenario 7: recent ownerless locks block and stale locks recover"
project_five="$(new_project locks)"
mkdir -p "$project_five/.dotagents/runs/.locked-run.lock"
assert_exit 3 bash "$WORKFLOW" start --project "$project_five" --run locked-run --scope standard
rmdir "$project_five/.dotagents/runs/.locked-run.lock"
mkdir -p "$project_five/.dotagents/runs/.locked-run.lock"
printf 'pid=999999\ncreated_at=1\nprocess_started=unavailable\ntoken=staleowner\n' > "$project_five/.dotagents/runs/.locked-run.lock/owner"
recovered="$(bash "$WORKFLOW" start --project "$project_five" --run locked-run --scope standard)"
assert_contains "$recovered" "current_stage: 1"

mkdir -p "$project_five/.dotagents/runs/.live-old.lock"
printf 'pid=%s\ncreated_at=1\nprocess_started=unavailable\ntoken=liveowner\n' "$$" > "$project_five/.dotagents/runs/.live-old.lock/owner"
assert_exit 3 bash "$WORKFLOW" start --project "$project_five" --run live-old --scope standard
unlink "$project_five/.dotagents/runs/.live-old.lock/owner"
rmdir "$project_five/.dotagents/runs/.live-old.lock"

echo "scenario 8: PID reuse shape is reclaimed by start identity"
project_six="$(new_project pid-reuse)"
mkdir -p "$project_six/.dotagents/runs/.pid-reuse.lock"
printf 'pid=%s\ncreated_at=%s\nprocess_started=definitely-not-this-process\ntoken=reusedowner\n' "$$" "$(date +%s)" > "$project_six/.dotagents/runs/.pid-reuse.lock/owner"
pid_output="$(bash "$WORKFLOW" start --project "$project_six" --run pid-reuse --scope standard)"
assert_contains "$pid_output" "run: pid-reuse"

echo "scenario 9: state corruption and incomplete verification fail closed"
assert_exit 3 bash "$WORKFLOW" verify --project "$project_two" --run imported-plan
sed 's/^state_version=1$/state_version=2/' "$project_two/.dotagents/runs/imported-plan/state" > "$project_two/.dotagents/runs/imported-plan/state.tmp"
mv "$project_two/.dotagents/runs/imported-plan/state.tmp" "$project_two/.dotagents/runs/imported-plan/state"
assert_exit 3 bash "$WORKFLOW" status --project "$project_two" --run imported-plan

echo "scenario 10: a nested Git path is rejected in favor of the worktree root"
mkdir -p "$project_one/packages/app"
assert_exit 3 bash "$WORKFLOW" start --project "$project_one/packages/app" --run nested --scope standard

echo "scenario 11: malformed contracts fail without creating state"
project_seven="$(new_project contract)"
bad_contract="$TEST_ROOT/bad-workflow.toml"
sed 's/^requires_approval = true$/requires_approval = false/' "$REPO_ROOT/agents/workflows/product-development/workflow.toml" > "$bad_contract"
assert_exit 3 env DOTAGENTS_WORKFLOW_FILE="$bad_contract" bash "$WORKFLOW" start --project "$project_seven" --run bad-contract --scope standard
[[ ! -e "$project_seven/.dotagents/runs/bad-contract" ]] || fail "invalid contract created run state"

duplicate_contract="$TEST_ROOT/duplicate-workflow.toml"
awk '$0 == "artifact = \"02-domain\"" { $0 = "artifact = \"01-interview\"" } { print }' "$REPO_ROOT/agents/workflows/product-development/workflow.toml" > "$duplicate_contract"
assert_exit 3 env DOTAGENTS_WORKFLOW_FILE="$duplicate_contract" bash "$WORKFLOW" start --project "$project_seven" --run duplicate-contract --scope standard
[[ ! -e "$project_seven/.dotagents/runs/duplicate-contract" ]] || fail "duplicate artifact contract created run state"

echo "scenario 12: concurrent approvals permit exactly one state transition"
project_eight="$(new_project concurrent-approval)"
bash "$WORKFLOW" start --project "$project_eight" --run approval-race --scope standard >/dev/null
write_artifact "$project_eight" approval-race 1
pids=()
for attempt in 1 2 3 4 5 6 7 8; do
  bash "$WORKFLOW" approve --project "$project_eight" --run approval-race --stage 1 --user-approved > "$TEST_ROOT/approval-$attempt.out" 2>&1 &
  pids+=("$!")
done
approval_successes=0
approval_failures=0
for pid in "${pids[@]}"; do
  if wait "$pid"; then
    approval_successes=$((approval_successes + 1))
  else
    approval_failures=$((approval_failures + 1))
  fi
done
[[ "$approval_successes" -eq 1 ]] || fail "expected one concurrent approval success, got $approval_successes"
[[ "$approval_failures" -eq 7 ]] || fail "expected seven concurrent approval failures, got $approval_failures"
race_status="$(bash "$WORKFLOW" status --project "$project_eight" --run approval-race)"
assert_contains "$race_status" "current_stage: 2"
assert_contains "$race_status" "approved_through: 1"

echo "scenario 13: approved artifacts are immutable evidence"
project_nine="$(new_project immutable-artifacts)"
bash "$WORKFLOW" start --project "$project_nine" --run immutable-run --scope standard >/dev/null
write_artifact "$project_nine" immutable-run 1
cp "$project_nine/docs/workflows/immutable-run/01-interview.md" "$TEST_ROOT/immutable-original.md"
bash "$WORKFLOW" approve --project "$project_nine" --run immutable-run --stage 1 --user-approved >/dev/null
printf '\nmutation\n' >> "$project_nine/docs/workflows/immutable-run/01-interview.md"
assert_exit 3 bash "$WORKFLOW" status --project "$project_nine" --run immutable-run
write_artifact "$project_nine" immutable-run 2
assert_exit 3 bash "$WORKFLOW" approve --project "$project_nine" --run immutable-run --stage 2 --user-approved
cp "$TEST_ROOT/immutable-original.md" "$project_nine/docs/workflows/immutable-run/01-interview.md"
restored_status="$(bash "$WORKFLOW" status --project "$project_nine" --run immutable-run)"
assert_contains "$restored_status" "current_stage: 2"
bash "$WORKFLOW" approve --project "$project_nine" --run immutable-run --stage 2 --user-approved >/dev/null
fake_hash_dir="$TEST_ROOT/fake-hash-bin"
mkdir -p "$fake_hash_dir"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'exit 1'
} > "$fake_hash_dir/shasum"
chmod +x "$fake_hash_dir/shasum"
assert_exit 3 env PATH="$fake_hash_dir:$PATH" bash "$WORKFLOW" status --project "$project_nine" --run immutable-run

echo "scenario 14: adopt recovers an empty run directory after state loss"
project_ten="$(new_project lost-state)"
bash "$WORKFLOW" start --project "$project_ten" --run recovered-run --scope standard >/dev/null
write_artifact "$project_ten" recovered-run 1
unlink "$project_ten/.dotagents/runs/recovered-run/state"
recovered_state="$(bash "$WORKFLOW" adopt --project "$project_ten" --run recovered-run --scope standard --through 1 --user-approved)"
assert_contains "$recovered_state" "current_stage: 2"
assert_contains "$recovered_state" "approved_through: 1"

echo "All workflow scenarios passed."
