#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd -P)"

usage() {
  echo 'Usage: run.sh search <query> | retrieve <ids> | list | legacy-scan [path] [options] | --version'
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  search|retrieve|list|legacy-scan|--version) ;;
  *) usage >&2; exit 2 ;;
esac

for tool in python3 node npm npx; do
  command -v "$tool" >/dev/null 2>&1 || { echo "error: $tool is required for Modern Web Guidance" >&2; exit 1; }
done

version="$(python3 - "$REPO_ROOT/agents/registry/sources.lock" <<'PY'
import re
import sys
from pathlib import Path

if sys.version_info < (3, 11):
    sys.exit('error: Modern Web Guidance runner requires Python 3.11 or newer')
import tomllib

try:
    data = tomllib.loads(Path(sys.argv[1]).read_text())
    sources = [s for s in data.get('sources', []) if s.get('id') == 'googlechrome-modern-web-guidance']
    version = sources[0].get('npm_version') if len(sources) == 1 else None
    if not isinstance(version, str) or not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version):
        sys.exit('error: sources.lock must pin one exact Modern Web Guidance npm_version')
except (OSError, tomllib.TOMLDecodeError) as error:
    sys.exit(f'error: cannot read Modern Web Guidance version lock: {error}')
print(version)
PY
)"

node_major="$(node -p 'process.versions.node.split(".")[0]')"
if [[ ! "$node_major" =~ ^[0-9]+$ || "$node_major" -lt 22 ]]; then
  echo 'error: Modern Web Guidance requires Node.js 22 or newer' >&2
  exit 1
fi

# Resolve the prefix with workspace discovery enabled so npx reads the root .npmrc.
# At the root itself, workspaces=true can make npm prefix reject workspace mode.
caller_dir="$(pwd -P)"
npm_dir="$(npm prefix 2>/dev/null || npm prefix --workspaces=false)"
cd -- "$npm_dir"

# npm resolves the pinned package once. Restore the caller's directory for the CLI.
DISABLE_TELEMETRY=1 exec npx --yes --workspaces=false --package="modern-web-guidance@$version" -- \
  /bin/sh -c 'cd -- "$1" && shift && exec modern-web-guidance "$@"' \
  modern-web-guidance "$caller_dir" "$@"
