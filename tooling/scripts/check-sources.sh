#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
SKILLS_FILE="${DOTAGENTS_SKILLS_FILE:-$REPO_ROOT/agents/registry/skills.toml}"
SOURCES_FILE="${DOTAGENTS_SOURCES_FILE:-$REPO_ROOT/agents/registry/sources.lock}"
GH_BIN="${GH_BIN:-gh}"

fail() {
  echo "error: $*" >&2
  exit 1
}

command -v "$GH_BIN" >/dev/null 2>&1 || fail "GitHub CLI is required for source verification"
command -v python3 >/dev/null 2>&1 || fail "Python 3.11 or newer is required for source verification"

exec python3 -IB - "$SCRIPT_DIR" "$SKILLS_FILE" "$SOURCES_FILE" "$GH_BIN" <<'PY'
from pathlib import Path
import subprocess
import sys
from urllib.parse import quote

if sys.version_info < (3, 11):
    sys.exit("error: Python 3.11 or newer is required for source verification")
script_dir, skills_file, sources_file, gh = sys.argv[1:]
sys.path.insert(0, script_dir)
from external_skills import REVISION, keyed, read_toml, require, safe_relative, source_url

github = "https://github.com/"
try:
    skills = keyed(read_toml(Path(skills_file))["skills"], allow_owned_ids=True)
    sources = keyed(read_toml(Path(sources_file))["sources"])
    checks = []
    for name, skill in skills.items():
        if skill.get("kind") == "owned":
            continue
        require(skill.get("kind") == "external", f"invalid skill kind: {name}")
        source_id = skill.get("source_id")
        require(isinstance(source_id, str) and source_id in sources,
                f"external skill references unlocked source: {name}")
        path = safe_relative(skill.get("path"))
        require(path.name == "SKILL.md" and len(path.parts) > 1,
                f"skill must have a repository-relative directory: {name}")
        source = sources[source_id]
        url = source.get("url")
        require(isinstance(url, str) and url.startswith(github),
                f"unsupported source URL for {source_id}")
        repository = source_url(url).removeprefix(github).removesuffix(".git")
        revision = source.get("revision")
        require(isinstance(revision, str) and REVISION.fullmatch(revision),
                f"unsafe pinned source revision: {source_id}")
        checks.append((f"{source_id}:{path}", f"repos/{repository}/contents/{quote(str(path))}?ref={revision}"))
    require(checks, "no external skill paths found")

    failed = False
    for label, endpoint in checks:
        result = subprocess.run([gh, "api", endpoint, "--silent"], stdout=subprocess.DEVNULL)
        if result.returncode == 0:
            print(f"ok: {label}")
        else:
            print(f"error: could not verify pinned source path: {label}", file=sys.stderr)
            failed = True
except (ValueError, KeyError, OSError) as error:
    sys.exit(f"error: {error}")

if failed:
    sys.exit(1)
print("All pinned source paths exist.")
PY
