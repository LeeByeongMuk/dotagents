#!/usr/bin/env bash
# Report whether the tools this repository depends on are installed.
# Exit 1 when a required tool is missing. Optional tools only warn.
set -euo pipefail

missing=0

check() {
  local kind="$1" name="$2" purpose="$3"
  if command -v "$name" >/dev/null 2>&1; then
    echo "ok: $name ($purpose)"
  elif [[ "$kind" == "required" ]]; then
    echo "missing: $name ($purpose)" >&2
    missing=1
  else
    echo "optional: $name is not installed ($purpose)"
  fi
}

check required git   "install manifest, hooks, repository checks"
check required bash  "all tooling scripts"
check required jq    "commit hook input, eval reports"
check required rg    "secret and hardcoded path scan in check.sh"
check optional gh    "check-sources.sh and pull requests"
check optional shasum "workflow state checksums (sha256sum also works)"

if [[ "$missing" -ne 0 ]]; then
  echo >&2
  echo "Install the missing tools, then rerun. On macOS: make deps (Homebrew). On Debian/Ubuntu: sudo apt install git jq ripgrep gh" >&2
  exit 1
fi
echo "All required tools are installed."
