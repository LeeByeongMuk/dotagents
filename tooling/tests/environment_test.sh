#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-environment-test.XXXXXX")"
trap 'rm -r "$TEST_ROOT"' EXIT
fail() { echo "test failed: $*" >&2; exit 1; }
profile="$REPO_ROOT/environment/profile.sh"
bash -n "$profile"
bash -n "$REPO_ROOT/environment/compare.sh"
sh -n "$REPO_ROOT/environment/source/dot_config/dotagents-environment/shell.sh"

echo 'scenario: omitted paths and invalid commands cannot invoke chezmoi'
mkdir "$TEST_ROOT/destination"
cat > "$TEST_ROOT/chezmoi-stub" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$ENVIRONMENT_TEST_ARGS"
STUB
chmod +x "$TEST_ROOT/chezmoi-stub"
export ENVIRONMENT_TEST_ARGS="$TEST_ROOT/args"
if CHEZMOI_BIN="$TEST_ROOT/chezmoi-stub" "$profile" apply --destination "$TEST_ROOT/destination" > /dev/null 2>&1; then
  fail 'apply accepted omitted isolation paths'
fi
[[ ! -e "$ENVIRONMENT_TEST_ARGS" ]] || fail 'incomplete arguments invoked chezmoi'
if CHEZMOI_BIN="$TEST_ROOT/chezmoi-stub" "$profile" update > /dev/null 2>&1; then
  fail 'unsupported command was accepted'
fi

echo 'scenario: preview forwards all isolated paths and never applies'
mkdir "$TEST_ROOT/source with spaces"
printf '%s\n' '# user-selected config' > "$TEST_ROOT/config.toml"
CHEZMOI_BIN="$TEST_ROOT/chezmoi-stub" "$profile" preview \
  --source "$TEST_ROOT/source with spaces" --destination "$TEST_ROOT/destination" \
  --config "$TEST_ROOT/config.toml" --state "$TEST_ROOT/state/db" --cache "$TEST_ROOT/cache"
for value in "$TEST_ROOT/source with spaces" "$TEST_ROOT/destination" "$TEST_ROOT/config.toml" "$TEST_ROOT/state/db" "$TEST_ROOT/cache" --error-on-conflict diff; do
  grep -Fxq -- "$value" "$ENVIRONMENT_TEST_ARGS" || fail "missing argument: $value"
done
! grep -Fxq apply "$ENVIRONMENT_TEST_ARGS" || fail 'preview invoked apply'

echo 'scenario: shell defaults preserve choices and add local bin only once'
mkdir -p "$TEST_ROOT/shell-home/.local/bin"
HOME="$TEST_ROOT/shell-home" bash -c '
  set -eu
  EDITOR=my-editor VISUAL=my-visual PAGER=my-pager
  . "$1"
  first_path="$PATH"
  . "$1"
  [[ "$EDITOR" == my-editor && "$VISUAL" == my-visual && "$PAGER" == my-pager ]]
  [[ "$PATH" == "$first_path" && "$PATH" == "$HOME/.local/bin:"* ]]
  unset EDITOR VISUAL PAGER
  . "$1"
  [[ "$EDITOR" == vi && "$VISUAL" == vi && "$PAGER" == less ]]
' _ "$REPO_ROOT/environment/source/dot_config/dotagents-environment/shell.sh" || fail 'shell fragment did not preserve user choices'
git_fragment="$REPO_ROOT/environment/source/dot_config/dotagents-environment/git.inc"
[[ "$(git config --file "$git_fragment" fetch.prune)" == true ]] || fail 'Git fragment is unusable'
[[ "$(git config --file "$git_fragment" merge.conflictStyle)" == diff3 ]] || fail 'Git conflict style missing'
! git config --file "$git_fragment" --get-regexp '^(user|credential|url|include)\.' > /dev/null || fail 'Git fragment owns local identity or auth'

real_chezmoi="${CHEZMOI_BIN:-}"
if [[ -z "$real_chezmoi" ]]; then
  real_chezmoi="$(command -v chezmoi || true)"
fi
if [[ -z "$real_chezmoi" ]]; then
  echo 'skip: real chezmoi integration (optional; set CHEZMOI_BIN to an existing binary)'
  exit 0
fi
command -v "$real_chezmoi" >/dev/null || fail 'CHEZMOI_BIN is not executable'
echo "scenario: real chezmoi integration ($("$real_chezmoi" --version))"
integration="$TEST_ROOT/real integration"
mkdir -p "$integration/destination" "$integration/config"
printf '%s\n' '# existing profile config' > "$integration/config/chezmoi.toml"
cp "$integration/config/chezmoi.toml" "$integration/config-before"
for name in .gitconfig .zshrc .bashrc; do
  printf '%s\n' 'existing user configuration' > "$integration/destination/$name"
done
run_profile() {
  CHEZMOI_BIN="$real_chezmoi" "$profile" "$1" \
    --source "$integration/source" --destination "$integration/destination" \
    --config "$integration/config/chezmoi.toml" --state "$integration/state/db" --cache "$integration/cache"
}
run_profile init > /dev/null
[[ -d "$integration/source/.git" ]] || fail 'init did not initialize the source repository'
[[ ! -e "$integration/destination/.config" ]] || fail 'init applied files'
cmp -s "$integration/config-before" "$integration/config/chezmoi.toml" || fail 'init overwrote user config'
if run_profile init > /dev/null 2>&1; then fail 'init accepted an existing source'; fi
run_profile preview > "$TEST_ROOT/diff"
grep -q git.inc "$TEST_ROOT/diff" || fail 'preview missed the Git fragment'
[[ ! -e "$integration/destination/.config" ]] || fail 'preview applied files'
mkdir -p "$integration/destination/.config/dotagents-environment"
printf '%s\n' '# pre-existing user fragment' > "$integration/destination/.config/dotagents-environment/git.inc"
if run_profile apply < /dev/null > "$TEST_ROOT/initial-conflict" 2>&1; then fail 'first apply overwrote a pre-existing fragment'; fi
[[ "$(cat "$integration/destination/.config/dotagents-environment/git.inc")" == '# pre-existing user fragment' ]] || fail 'first conflict lost existing content'
rm "$integration/destination/.config/dotagents-environment/git.inc"
run_profile apply
deployed="$integration/destination/.config/dotagents-environment"
cmp -s "$git_fragment" "$deployed/git.inc" || fail 'apply did not deploy the Git fragment'
[[ ! -L "$deployed/git.inc" ]] || fail 'explicit apply unexpectedly linked the source'
run_profile apply
[[ -z "$(run_profile status)" ]] || fail 'repeat apply left drift'
printf '%s\n' '# source change' >> "$integration/source/dot_config/dotagents-environment/git.inc"
! grep -q 'source change' "$deployed/git.inc" || fail 'source edit became live without apply'
[[ -n "$(run_profile status)" ]] || fail 'source change was not detected'
run_profile apply
grep -q 'source change' "$deployed/git.inc" || fail 'apply did not update an unedited target'
printf '%s\n' '# user edit' >> "$deployed/git.inc"
printf '%s\n' '# next source change' >> "$integration/source/dot_config/dotagents-environment/git.inc"
cp "$deployed/git.inc" "$TEST_ROOT/edited-before"
if run_profile apply > "$TEST_ROOT/conflict" 2>&1; then fail 'apply did not fail on a user edit'; fi
cmp -s "$TEST_ROOT/edited-before" "$deployed/git.inc" || fail 'conflict overwrote the user edit'
for name in .gitconfig .zshrc .bashrc; do
  [[ "$(cat "$integration/destination/$name")" == 'existing user configuration' ]] || fail "profile changed $name"
done
echo 'All environment scenarios passed.'
