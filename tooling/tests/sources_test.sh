#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-sources-test.XXXXXX")"
trap 'rm -r "$TEST_ROOT"' EXIT

fail() { echo "test failed: $*" >&2; exit 1; }

fake_gh="$TEST_ROOT/gh"
request_log="$TEST_ROOT/requests"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'printf '\''%s\n'\'' "$*" >> "$SOURCE_CHECK_LOG"'
} > "$fake_gh"
chmod +x "$fake_gh"

SOURCE_CHECK_LOG="$request_log" GH_BIN="$fake_gh" "$REPO_ROOT/tooling/scripts/check-sources.sh" >/dev/null
[[ "$(wc -l < "$request_log" | tr -d ' ')" -eq 7 ]] || fail "expected seven external source path checks"
grep -Fq 'repos/garrytan/gstack/contents/office-hours/SKILL.md?ref=' "$request_log" || fail "office-hours source path is incorrect"
grep -Fq 'repos/garrytan/gstack/contents/autoplan/SKILL.md?ref=' "$request_log" || fail "autoplan source path is incorrect"
grep -Fq 'repos/garrytan/gstack/contents/review/SKILL.md?ref=' "$request_log" || fail "review source path is incorrect"
grep -Fq 'repos/garrytan/gstack/contents/qa/SKILL.md?ref=' "$request_log" || fail "qa source path is incorrect"
grep -Fq 'repos/obra/superpowers/contents/skills/writing-plans/SKILL.md?ref=' "$request_log" || fail "Superpowers source path is incorrect"
grep -Fq 'repos/mattpocock/skills/contents/skills/productivity/grilling/SKILL.md?ref=' "$request_log" || fail "grilling source path is incorrect"
grep -Fq 'repos/GoogleChrome/modern-web-guidance/contents/skills/modern-web-guidance/SKILL.md?ref=' "$request_log" || fail "Modern Web Guidance source path is incorrect"
if grep -Fq '/contents/.agents/skills/gstack-' "$request_log"; then
  fail "host installation path leaked into source-relative registry path"
fi

verify_sources="$REPO_ROOT/tooling/scripts/check-sources.sh"
fixture_skills="$TEST_ROOT/skills.toml"
fixture_sources="$TEST_ROOT/sources.lock"
revision=0123456789abcdef0123456789abcdef01234567
cat > "$fixture_sources" <<EOF
  [[sources]] # Formatting and comments are part of TOML.
  id='example'
  url = 'https://github.com/Example/repo.git' # Verify the Contents API path.
  revision="$revision"
EOF
cat > "$fixture_skills" <<'EOF'
[[skills]]
id = "first"
kind = "external"
source_id = "example"
path = "first/SKILL.md"

  [[skills]] # This entry used to be silently skipped.
  id='second'
  kind="external"
  source_id="example" # Use the same TOML rules as the installer.
  path = 'second with spaces/SKILL.md'
EOF

run_fixture() {
  DOTAGENTS_SKILLS_FILE="$fixture_skills" DOTAGENTS_SOURCES_FILE="$fixture_sources" \
    SOURCE_CHECK_LOG="$request_log" GH_BIN="$fake_gh" "$verify_sources"
}

: > "$request_log"
run_fixture >/dev/null
[[ "$(wc -l < "$request_log" | tr -d ' ')" -eq 2 ]] || fail "valid TOML formatting skipped a source check"
grep -Fq "repos/Example/repo/contents/second%20with%20spaces/SKILL.md?ref=$revision" "$request_log" \
  || fail "source path or revision was not decoded from TOML"
cp "$fixture_skills" "$TEST_ROOT/valid-skills.toml"

for malformed_entry in \
  'path = "third/SKILL.md"' \
  'source_id = "example"' \
  $'source_id = ["example"]\npath = "third/SKILL.md"' \
  $'source_id = "missing"\npath = "third/SKILL.md"' \
  $'source_id = "example"\npath = "../third/SKILL.md"' \
  $'source_id = "example"\npath = ['; do
  cp "$TEST_ROOT/valid-skills.toml" "$fixture_skills"
  printf '\n[[skills]]\nid = "third"\nkind = "external"\n%s\n' "$malformed_entry" >> "$fixture_skills"
  : > "$request_log"
  if run_fixture >/dev/null 2>&1; then
    fail "source verification accepted a malformed external entry: $malformed_entry"
  fi
  [[ ! -s "$request_log" ]] || fail "source verification contacted GitHub before validating the registry"
done

failing_gh="$TEST_ROOT/gh-fail"
failure_output="$TEST_ROOT/failure-output"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'exit 1'
} > "$failing_gh"
chmod +x "$failing_gh"
if GH_BIN="$failing_gh" "$REPO_ROOT/tooling/scripts/check-sources.sh" > "$failure_output" 2>&1; then
  fail "source verification should fail when GitHub API is unavailable"
fi
grep -Fq 'could not verify pinned source path' "$failure_output" || fail "source failure diagnostic is inaccurate"
if grep -Fq 'pinned source path is missing' "$failure_output"; then
  fail "generic API failure was misreported as a missing path"
fi

echo "External source registry passed."
