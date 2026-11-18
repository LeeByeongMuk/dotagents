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
    (binaries / 'npm').write_text('#!/bin/sh\n[ "$1" = prefix ] && printf "%s\\n" "$PWD"\n')
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
    npx_args = ['--yes', '--workspaces=false', '--package=modern-web-guidance@' + source['npm_version'], '--',
                '/bin/sh', '-c', 'cd -- "$1" && shift && exec modern-web-guidance "$@"',
                'modern-web-guidance', str(project)]
    for args in [('search', query), ('retrieve', 'dialog,light-dismiss-a-dialog'), ('list',),
                 ('legacy-scan', 'src with spaces', '--json'), ('--version',)]:
        result = run(*args)
        assert result.returncode == 0, result.stderr
        received = json.loads(log.read_text())
        assert received['args'] == [*npx_args, *args]
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
    assert json.loads(log.read_text())['args'][2] == '--package=modern-web-guidance@2.3.4'
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

    # A real npm process can relocate the child even when npx itself starts in the right directory.
    if all(shutil.which(tool) for tool in ('npm', 'npx', 'node')) and int(subprocess.check_output(
            ['node', '-p', 'process.versions.node.split(".")[0]'])) >= 22:
        workspace = project / 'packages' / 'web'
        sibling = project / 'packages' / 'other'
        caller = workspace / 'nested directory'
        caller.mkdir(parents=True)
        sibling.mkdir()
        npm_config = project / '.npmrc'
        project_settings = 'workspaces=true\nregistry=https://root-registry.invalid/\nproxy=https://root-proxy.invalid/\n'
        npm_config.write_text(project_settings)
        user_config = root / 'user.npmrc'
        user_settings = 'registry=https://user-registry.invalid/\n'
        user_config.write_text(user_settings)
        global_prefix = root / 'npm installation'
        global_config = global_prefix / 'etc' / 'npmrc'
        global_config.parent.mkdir(parents=True)
        global_settings = 'https-proxy=https://global-proxy.invalid/\n'
        global_config.write_text(global_settings)
        manifest = {'name': 'modern-web-guidance', 'version': source['npm_version'], 'bin': './fixture.cjs'}
        (project / 'package.json').write_text(json.dumps({
            'name': 'root', 'workspaces': ['packages/*'], 'dependencies': {'modern-web-guidance': source['npm_version']},
        }))
        for directory in (workspace, sibling):
            (directory / 'package.json').write_text(json.dumps({'name': directory.name}))
        package = project / 'node_modules' / 'modern-web-guidance'
        package.mkdir(parents=True)
        (package / 'package.json').write_text(json.dumps(manifest))
        binary = package / 'fixture.cjs'
        binary.write_text('''#!/usr/bin/env node
const { readFileSync } = require('node:fs');
console.log(JSON.stringify({
    cwd: process.cwd(),
    args: process.argv.slice(2),
    policy: readFileSync('.mwgrc', 'utf8'),
    relative: readFileSync(process.argv[3], 'utf8'),
    telemetry: process.env.DISABLE_TELEMETRY,
    registry: process.env.npm_config_registry,
    proxy: process.env.npm_config_proxy,
    httpsProxy: process.env.npm_config_https_proxy,
}));
''')
        binary.chmod(0o755)
        local_bins = package.parent / '.bin'
        local_bins.mkdir()
        (local_bins / 'modern-web-guidance').symlink_to(binary)
        relative = 'src with spaces; ' + query
        offline = {key: value for key, value in os.environ.items() if not key.lower().startswith('npm_config_')}
        offline.update(npm_config_offline='true', npm_config_cache=str(root / 'npm-cache'),
                       npm_config_userconfig=str(user_config), npm_config_prefix=str(global_prefix),
                       npm_config_update_notifier='false', DISABLE_TELEMETRY='0')
        args = ['legacy-scan', relative, '--json']
        for directory, marker in [(project, 'root'), (caller, 'nested')]:
            (directory / '.mwgrc').write_text(marker + ' policy')
            (directory / relative).write_text(marker + ' scan target')
            real = subprocess.run([str(runner), *args], cwd=directory, env=offline, text=True, capture_output=True)
            assert real.returncode == 0, real.stderr
            assert json.loads(real.stdout) == {
                'cwd': str(directory), 'args': args, 'policy': marker + ' policy',
                'relative': marker + ' scan target', 'telemetry': '1',
                'registry': 'https://root-registry.invalid/', 'proxy': 'https://root-proxy.invalid/',
                'httpsProxy': 'https://global-proxy.invalid/',
            }
            assert all(not (directory / injected).exists() for injected in ('SHOULD_NOT_EXIST', 'ALSO_NOT'))
        assert npm_config.read_text() == project_settings
        assert user_config.read_text() == user_settings
        assert global_config.read_text() == global_settings
    else:
        print('Skipping real npm workspace fixture (Node.js 22, npm, and npx required).')

print('Modern Web Guidance runner passed.')
PY
