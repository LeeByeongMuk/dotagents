#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
export MWG_TEST_REPO="$REPO_ROOT"

python3 - <<'PY'
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib

repo = Path(os.environ['MWG_TEST_REPO'])
runner_path = Path('agents/integrations/skills/modern-web-guidance/run.sh')
sources_path = Path('agents/registry/sources.lock')
registry = tomllib.loads((repo / 'agents/registry/skills.toml').read_text())
skill = next(s for s in registry['skills'] if s['id'] == 'modern-web-guidance')
assert skill['kind'] == 'external' and skill['optional'] and not skill['enabled_by_default']
assert skill['license'] == 'Apache-2.0 AND CC-BY-4.0'
source = next(s for s in tomllib.loads((repo / sources_path).read_text())['sources']
              if s['id'] == skill['source_id'])

with tempfile.TemporaryDirectory(prefix='dotagents mwg test ') as directory:
    root = Path(directory).resolve()
    checkout, project, binaries = (root / name for name in ('checkout', 'project with spaces', 'bin'))
    for path in (checkout / runner_path.parent, checkout / sources_path.parent, project, binaries):
        path.mkdir(parents=True)
    runner = checkout / runner_path
    shutil.copy2(repo / runner_path, runner)
    lock = checkout / sources_path
    shutil.copy2(repo / sources_path, lock)
    original_lock = lock.read_text()
    log = root / 'npx.json'
    (binaries / 'node').write_text('#!/bin/sh\nprintf "%s\\n" "${MWG_TEST_NODE_MAJOR:-22}"\n')
    (binaries / 'npx').write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
Path(os.environ['MWG_TEST_LOG']).write_text(json.dumps({
    'args': sys.argv[1:], 'cwd': os.getcwd(),
    'telemetry': os.environ.get('DISABLE_TELEMETRY'),
}))
sys.exit(int(os.environ.get('MWG_TEST_EXIT', '0')))
''')
    for binary in binaries.iterdir():
        binary.chmod(0o755)
    env = dict(os.environ, PATH=str(binaries) + os.pathsep + os.environ['PATH'],
               MWG_TEST_LOG=str(log), DISABLE_TELEMETRY='0')

    def run(*args, custom=None):
        log.unlink(missing_ok=True)
        return subprocess.run([str(runner), *args], cwd=project,
                              env=dict(env, **(custom or {})), text=True, capture_output=True)

    # Treat query text as one argument, even when it contains shell syntax.
    query = 'dialog focus; $(touch SHOULD_NOT_EXIST) `touch ALSO_NOT`'
    for args in [('search', query), ('retrieve', 'dialog,light-dismiss-a-dialog'), ('list',),
                 ('legacy-scan', 'src with spaces', '--json'), ('--version',)]:
        result = run(*args)
        assert result.returncode == 0, result.stderr
        received = json.loads(log.read_text())
        assert received['args'] == ['--yes', 'modern-web-guidance@' + source['npm_version'], *args]
        assert received['cwd'] == str(project) and received['telemetry'] == '1'
    assert not list(project.iterdir()), 'runner must not write to the target project'
    assert run('search', 'dialog', custom={'MWG_TEST_EXIT': '17'}).returncode == 17

    # Installer/configuration commands must never reach the upstream CLI.
    for args in [(), ('install',), ('update',), ('uninstall',),
                 ('set-allow-origin-trials',), ('set-allow-volatile-features',)]:
        assert run(*args).returncode == 2
        assert not log.exists()
    assert run('--help').returncode == 0 and not log.exists()

    # The lock owns the runtime version; it must not fall back to latest.
    lock.write_text(original_lock.replace('npm_version = "' + source['npm_version'] + '"',
                                          'npm_version = "2.3.4"'))
    assert run('--version').returncode == 0
    assert json.loads(log.read_text())['args'][1] == 'modern-web-guidance@2.3.4'
    for bad_pin in ['latest', '^1.0.1', '', '1.0.1; touch unexpected']:
        lock.write_text(original_lock.replace('npm_version = "' + source['npm_version'] + '"',
                                              'npm_version = ' + json.dumps(bad_pin)))
        result = run('--version')
        assert result.returncode != 0 and 'exact' in result.stderr and not log.exists()
    lock.write_text('lock_version = [')
    result = run('--version')
    assert result.returncode != 0 and 'version lock' in result.stderr and not log.exists()
    lock.unlink()
    result = run('--version')
    assert result.returncode != 0 and 'version lock' in result.stderr and not log.exists()
    lock.write_text(original_lock)
    for major in ['20', 'invalid']:
        result = run('--version', custom={'MWG_TEST_NODE_MAJOR': major})
        assert result.returncode != 0 and 'Node.js 22' in result.stderr and not log.exists()

print('Modern Web Guidance runner passed.')
PY
