#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
export EXTERNAL_TEST_REPO="$REPO_ROOT"
python3 - <<'PY'
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

assert __import__('sys').version_info >= (3, 11), 'optional external-skills command tests require Python 3.11+'
ROOT = Path(os.environ['EXTERNAL_TEST_REPO'])
CLI = ROOT / 'tooling/scripts/external-skills.sh'
runtime = subprocess.run(['python3', '-c', 'import runpy, sys; sys.version_info = (3, 10); runpy.run_path(sys.argv[1], run_name="__main__")', str(ROOT / 'tooling/scripts/external_skills.py')], capture_output=True, text=True)
assert runtime.returncode != 0 and 'Python 3.11' in runtime.stderr and 'Traceback' not in runtime.stderr

def git(repo, *args):
    run = subprocess.run(['git', '-C', str(repo), '-c', 'core.hooksPath=/dev/null', *args],
                         capture_output=True, text=True)
    assert run.returncode == 0, run.stderr
    return run.stdout.strip()

def snapshot(root):
    entries = []
    for path in sorted(root.rglob('*')):
        name = str(path.relative_to(root))
        if path.is_symlink(): entries.append((name, 'link', os.readlink(path)))
        elif path.is_file(): entries.append((name, 'file', hashlib.sha256(path.read_bytes()).hexdigest()))
        elif path.is_dir(): entries.append((name, 'directory'))
    return entries

with tempfile.TemporaryDirectory(prefix='dotagents-external-test-') as directory:
    root = Path(directory).resolve()
    source, dest, state = (root / name for name in ('source', 'dest', 'state'))
    for path in (source, dest, state, root / 'home'): path.mkdir()
    env = dict(os.environ, HOME=str(root / 'home'), DOTAGENTS_SKILLS_FILE=str(root / 'skills.toml'),
               DOTAGENTS_SOURCES_FILE=str(root / 'sources.lock'))
    git(source, 'init', '-q')
    git(source, 'config', 'user.name', 'Fixture')
    git(source, 'config', 'user.email', 'fixture@example.test')
    (source / 'skills/sample').mkdir(parents=True)
    (source / 'assets').mkdir()
    (source / 'skills/sample/SKILL.md').write_text('---\nname: sample\ndescription: fixture\n---\nVersion one\n')
    (source / 'assets/support.txt').write_text('support one\n')
    (source / 'skills/sample/support').symlink_to('../../assets')
    (source / 'skills/sample/optional-output').symlink_to('../../assets/future-build-output')
    (source / 'install.sh').write_text('#!/bin/sh\ntouch SHOULD_NEVER_RUN\n')
    (source / '.gitattributes').write_text('assets/support.txt export-ignore\n')
    git(source, 'add', '.')
    git(source, 'commit', '-qm', 'version one')
    first = git(source, 'rev-parse', 'HEAD')
    (source / 'skills/sample/SKILL.md').write_text('---\nname: sample\ndescription: fixture\n---\nVersion two\n')
    (source / 'assets/support.txt').write_text('support two\n')
    git(source, 'add', '.')
    git(source, 'commit', '-qm', 'version two')
    second = git(source, 'rev-parse', 'HEAD')
    (source / 'LATEST_ONLY').write_text('remote HEAD must not be installed\n')
    git(source, 'add', '.')
    git(source, 'commit', '-qm', 'remote head')

    def registry(revision=first, path='skills/sample/SKILL.md', source_id='fixture', url=None):
        (root / 'skills.toml').write_text('schema_version = 1\n[[skills]]\nid = "external-sample"\nkind = "external"\nsource_id = ' + json.dumps(source_id) + '\npath = ' + json.dumps(path) + '\nhosts = ["codex"]\n')
        (root / 'sources.lock').write_text('lock_version = 1\n[[sources]]\nid = "fixture"\nurl = ' + json.dumps(url or source.as_uri()) + '\nrevision = ' + json.dumps(revision) + '\n')

    def run(action, *extra, ok=True, target=dest, cache=state, cli=CLI, custom_env=None):
        command = [str(cli), action]
        if action != 'list':
            command += ['external-sample', '--host', 'codex', '--dest', str(target), '--state-dir', str(cache)]
        result = subprocess.run(command + list(extra), capture_output=True, text=True, env=custom_env or env)
        assert (result.returncode == 0) == ok, (command, result.returncode, result.stdout, result.stderr)
        return result.stdout + result.stderr

    registry()
    print('scenario: previews and list/inspect do not fetch or write')
    before = snapshot(state), snapshot(dest)
    run('list')
    run('inspect')
    run('plan')
    run('install')
    assert before == (snapshot(state), snapshot(dest))

    print('scenario: install exact old pin with complete supporting assets; repeat without remote HEAD')
    run('install', '--apply')
    target = dest / 'external-sample'
    assert target.is_symlink() and first in os.readlink(target)
    assert 'Version one' in (target / 'SKILL.md').read_text()
    assert (target / 'support/support.txt').read_text() == 'support one\n'
    payload = state / 'checkouts/fixture' / first / 'payload'
    assert not (payload / 'LATEST_ONLY').exists()
    assert (payload / 'install.sh').is_file()
    assert not list(root.rglob('SHOULD_NEVER_RUN'))
    before = snapshot(state), snapshot(dest)
    run('install', '--apply')
    assert before == (snapshot(state), snapshot(dest))
    record_path = next((state / 'installs').glob('*.json'))
    assert json.loads(record_path.read_text())['revision'] == first

    print('scenario: explicit update follows changed lock, retaining old cache and unrelated skills')
    (dest / 'user-skill').mkdir()
    (dest / 'user-skill/SKILL.md').write_text('user content\n')
    registry(second)
    run('install', '--apply', ok=False)
    run('update')
    assert first in os.readlink(target)
    run('update', '--apply')
    assert second in os.readlink(target) and 'Version two' in (target / 'SKILL.md').read_text()
    assert payload.is_dir() and (dest / 'user-skill/SKILL.md').read_text() == 'user content\n'

    print('scenario: changed payloads and replaced targets are preserved for update and remove')
    original = (target / 'SKILL.md').read_bytes()
    (target / 'SKILL.md').write_bytes(original + b'user edit\n')
    assert 'modified; preserved' in run('update', '--apply', ok=False)
    assert 'modified; preserved' in run('remove', '--apply', ok=False)
    (target / 'SKILL.md').write_bytes(original)
    owned_link = os.readlink(target)
    target.unlink()
    target.write_text('user-owned replacement\n')
    before = snapshot(dest), record_path.read_bytes()
    run('update', '--apply', ok=False)
    run('remove', '--apply', ok=False)
    assert before == (snapshot(dest), record_path.read_bytes())
    target.unlink()
    target.symlink_to(owned_link)

    print('scenario: failed fetch/path lookup leaves old target and provenance intact')
    registry('0' * 40)
    before = os.readlink(target), record_path.read_bytes()
    run('update', '--apply', ok=False)
    assert before == (os.readlink(target), record_path.read_bytes())
    registry(second, path='skills/missing/SKILL.md')
    run('update', '--apply', ok=False)
    assert before == (os.readlink(target), record_path.read_bytes())
    assert not (state / '.external-skills.lock').exists()

    print('scenario: retired declarations and unavailable source still allow owned-only removal')
    (root / 'skills.toml').unlink()
    (root / 'sources.lock').unlink()
    source.rename(root / 'offline-source')
    run('remove')
    assert target.is_symlink()
    run('remove', '--apply')
    assert not target.exists() and not target.is_symlink() and not record_path.exists()
    assert (dest / 'user-skill/SKILL.md').read_text() == 'user content\n'
    (root / 'offline-source').rename(source)
    registry(second)
    run('update', '--apply', ok=False)
    target.symlink_to(root / 'foreign-missing')
    run('install', '--apply', ok=False)
    run('remove', '--apply', ok=False)
    assert os.readlink(target) == str(root / 'foreign-missing')
    target.unlink()

    print('scenario: replacements at lock acquisition preserve the target, record and cache')
    acquisition = root / 'at-lock-acquisition.py'
    acquisition.write_text('''import os, runpy, signal, sys
from pathlib import Path
real_mkdir = Path.mkdir
def change_at_lock(path, *args, **kwargs):
    real_mkdir(path, *args, **kwargs)
    if path.name != ".external-skills.lock":
        return
    if os.environ.get("ACQUISITION_SIGTERM"):
        os.kill(os.getpid(), signal.SIGTERM)
        return
    target = Path(os.environ["ACQUISITION_TARGET"])
    target.unlink(missing_ok=True)
    if foreign := os.environ.get("ACQUISITION_FOREIGN_LINK"):
        target.symlink_to(foreign)
    else:
        target.write_text("user replacement at acquisition\\n")
Path.mkdir = change_at_lock
sys.argv = sys.argv[1:]
runpy.run_path(sys.argv[0], run_name="__main__")
''')
    race_dest, race_state, foreign = (root / name for name in ('race-dest', 'race-state', 'foreign-skill'))
    for directory in (race_dest, race_state, foreign):
        directory.mkdir()
    race_target = race_dest / 'external-sample'
    (foreign / 'SKILL.md').write_text('user-owned skill\n')
    race_command = ['python3', str(acquisition), str(ROOT / 'tooling/scripts/external_skills.py'), 'remove',
                    'external-sample', '--host', 'codex', '--dest', str(race_dest), '--state-dir', str(race_state), '--apply']
    for action, owned in [('remove', True), ('install', False), ('install', True), ('update', True)]:
        for linked in (True, False):
            registry(first)
            if owned:
                run('install', '--apply', target=race_dest, cache=race_state)
                race_previous = os.readlink(race_target)
            registry(second if action == 'update' else first)
            before = snapshot(race_state), snapshot(foreign)
            race_command[3] = action
            race_env = dict(env, ACQUISITION_TARGET=str(race_target), ACQUISITION_FOREIGN_LINK=str(foreign) if linked else '')
            result = subprocess.run(race_command, capture_output=True, text=True, env=race_env)
            assert result.returncode != 0 and 'target changed during operation; preserved' in result.stderr, (action, linked, result)
            if linked:
                assert race_target.is_symlink() and os.readlink(race_target) == str(foreign)
            else:
                assert not race_target.is_symlink() and race_target.read_text() == 'user replacement at acquisition\n'
            assert before == (snapshot(race_state), snapshot(foreign)), (action, linked)
            race_target.unlink()
            if owned:
                race_target.symlink_to(race_previous)
                run('remove', '--apply', target=race_dest, cache=race_state)

    print('scenario: a linked install record is refused even if its bytes match')
    registry(first)
    run('install', '--apply', target=race_dest, cache=race_state)
    race_record = next((race_state / 'installs').glob('*.json'))
    record_copy = root / 'record-copy.json'
    record_copy.write_bytes(race_record.read_bytes())
    race_command[3] = 'remove'
    result = subprocess.run(race_command, capture_output=True, text=True, env=dict(
        env, ACQUISITION_TARGET=str(race_record), ACQUISITION_FOREIGN_LINK=str(record_copy)))
    assert result.returncode != 0 and 'symlink path component refused' in result.stderr
    assert race_record.is_symlink() and os.readlink(race_record) == str(record_copy)
    assert race_target.is_symlink() and os.readlink(race_target) == json.loads(record_copy.read_bytes())['target']
    assert not (race_state / '.external-skills.lock').exists()
    race_record.unlink()
    race_record.write_bytes(record_copy.read_bytes())
    run('remove', '--apply', target=race_dest, cache=race_state)

    print('scenario: SIGTERM during lock acquisition releases our lock; contention preserves another lock')
    registry(first)
    before = snapshot(race_state), snapshot(race_dest)
    race_command[3] = 'install'
    result = subprocess.run(race_command, capture_output=True, text=True, env=dict(env, ACQUISITION_SIGTERM='1'))
    assert result.returncode != 0 and 'terminated' in result.stderr
    assert before == (snapshot(race_state), snapshot(race_dest))
    other_lock = race_state / '.external-skills.lock'
    other_lock.mkdir()
    before = snapshot(race_state), snapshot(race_dest)
    run('install', '--apply', target=race_dest, cache=race_state, ok=False)
    assert before == (snapshot(race_state), snapshot(race_dest))

    print('scenario: metadata and symlink boundaries fail before target mutation')
    for value in ('../outside/SKILL.md', '/absolute/SKILL.md', 'skills/../sample/SKILL.md'):
        registry(second, path=value)
        assert 'unsafe' in run('install', '--apply', ok=False)
        assert not target.exists()
    registry(second, source_id='../unsafe')
    run('install', '--apply', ok=False)
    registry('main')
    run('install', '--apply', ok=False)
    registry(second, url='https://example.test/source.git')
    run('install', '--apply', ok=False)
    registry(second)
    (root / 'legacy').symlink_to(dest)
    before = snapshot(dest)
    run('install', '--apply', target=root / 'legacy', ok=False)
    run('install', '--apply', target=root / 'legacy/subdir', ok=False)
    (root / 'state-link').symlink_to(state)
    run('install', '--apply', cache=root / 'state-link', ok=False)
    run('install', '--apply', target=ROOT, ok=False)
    run('install', '--apply', target=state, ok=False)
    assert before == snapshot(dest)

    print('scenario: unsafe upstream links fail before publication')
    (source / 'skills/sample/escape').symlink_to('../../../../outside')
    git(source, 'add', '.')
    git(source, 'commit', '-qm', 'unsafe symlink')
    unsafe = git(source, 'rev-parse', 'HEAD')
    registry(unsafe)
    before = snapshot(dest)
    assert 'symlink escapes' in run('install', '--apply', ok=False)
    assert before == snapshot(dest) and not (state / 'checkouts/fixture' / unsafe).exists()
    (source / 'skills/sample/escape').unlink()
    (source / 'skills/sample/cycle').symlink_to('cycle')
    git(source, 'add', '.')
    git(source, 'commit', '-qm', 'cyclic symlink')
    registry(git(source, 'rev-parse', 'HEAD'))
    run('install', '--apply', ok=False)
    assert before == snapshot(dest)

    print('scenario: link publication failure restores target and manifest')
    # Patch only the stdlib publication primitive in a separate test process; no
    # production fault-injection switch or external code execution is introduced.
    registry(second)
    injection = root / 'inject.py'
    injection.write_text('import os, runpy, sys\nreal = os.replace\ndef fail(source, target):\n    if str(target).endswith(".json"):\n        raise OSError("injected record publication failure")\n    return real(source, target)\nos.replace = fail\nsys.argv = sys.argv[1:]\nrunpy.run_path(sys.argv[0], run_name="__main__")\n')
    command = ['python3', str(injection), str(ROOT / 'tooling/scripts/external_skills.py'), 'install',
               'external-sample', '--host', 'codex', '--dest', str(dest), '--state-dir', str(state), '--apply']
    result = subprocess.run(command, capture_output=True, text=True, env=env)
    assert result.returncode != 0 and 'injected' in result.stderr
    assert not target.is_symlink() and not record_path.exists()
    run('install', '--apply')
    registry(first)
    previous_link, previous_record = os.readlink(target), record_path.read_bytes()
    command[3] = 'update'
    result = subprocess.run(command, capture_output=True, text=True, env=env)
    assert result.returncode != 0 and 'injected' in result.stderr
    assert (os.readlink(target), record_path.read_bytes()) == (previous_link, previous_record)
    registry(second)
    # A missing owned target can be repaired without adopting an unrelated one.
    target.unlink()
    assert 'status=missing' in run('inspect')
    run('update', '--apply')
    assert os.readlink(target) == previous_link
    run('remove', '--apply')

    print('scenario: post-publication failures keep a committed link/provenance pair')
    post_publication = root / 'post-publication.py'
    post_publication.write_text('''import os, runpy, signal, sys
from pathlib import Path
real_replace, real_unlink = os.replace, Path.unlink
def after_publication(message):
    if os.environ.get("USER_REPLACEMENT"):
        replacement = Path(os.environ["USER_REPLACEMENT"])
        if os.path.lexists(replacement):
            real_unlink(replacement)
        replacement.write_text("concurrent user replacement\\n")
    if os.environ.get("PUBLICATION_SIGTERM"):
        os.kill(os.getpid(), signal.SIGTERM)
    raise OSError(message)
def fail_replace(source, target):
    result = real_replace(source, target)
    if str(target).endswith(".json"):
        after_publication("injected after record publication")
    return result
def fail_unlink(path, *args, **kwargs):
    result = real_unlink(path, *args, **kwargs)
    if path.suffix == ".json" and path.parent.name == "installs":
        after_publication("injected after record removal")
    return result
os.replace, Path.unlink = fail_replace, fail_unlink
sys.argv = sys.argv[1:]
runpy.run_path(sys.argv[0], run_name="__main__")
''')
    command[1] = str(post_publication)
    command[3] = 'install'
    registry(first)
    result = subprocess.run(command, capture_output=True, text=True, env=env)
    assert result.returncode != 0 and 'after record publication' in result.stderr
    assert 'committed:' in result.stderr
    committed = json.loads(record_path.read_text())
    assert target.is_symlink() and os.readlink(target) == committed['target'] and committed['revision'] == first
    run('inspect')
    registry(second)
    command[3] = 'update'
    result = subprocess.run(command, capture_output=True, text=True, env=env)
    assert result.returncode != 0 and 'after record publication' in result.stderr
    assert 'committed:' in result.stderr
    committed = json.loads(record_path.read_text())
    assert target.is_symlink() and os.readlink(target) == committed['target'] and committed['revision'] == second
    run('inspect')
    command[3] = 'remove'
    result = subprocess.run(command, capture_output=True, text=True, env=env)
    assert result.returncode != 0 and 'after record removal' in result.stderr
    assert 'committed:' in result.stderr
    assert not os.path.lexists(target) and not record_path.exists()
    run('inspect')

    print('scenario: committed failures preserve concurrent user replacements')
    replacement_env = dict(env, USER_REPLACEMENT=str(target))
    registry(first)
    for action, revision in [('install', first), ('update', second), ('remove', second)]:
        registry(revision)
        command[3] = action
        result = subprocess.run(command, capture_output=True, text=True, env=replacement_env)
        assert result.returncode != 0 and 'committed:' in result.stderr
        assert target.is_file() and not target.is_symlink() and target.read_text() == 'concurrent user replacement\n'
        if action != 'remove':
            committed = json.loads(record_path.read_text())
            assert committed['revision'] == revision
            # Restore the recorded link only inside this fixture for the next case.
            target.unlink()
            target.symlink_to(committed['target'])
        else:
            assert not record_path.exists()
            run('remove', '--apply', ok=False)
            assert target.read_text() == 'concurrent user replacement\n'
            target.unlink()

    print('scenario: SIGTERM immediately after record publication keeps the new pair')
    command[3] = 'install'
    result = subprocess.run(command, capture_output=True, text=True, env=dict(env, PUBLICATION_SIGTERM='1'))
    assert result.returncode != 0 and 'committed:' in result.stderr and 'terminated' in result.stderr
    committed = json.loads(record_path.read_text())
    assert target.is_symlink() and os.readlink(target) == committed['target']
    run('inspect')
    run('remove', '--apply')

    print('scenario: same-repository primary and linked worktree remain protected')
    primary = root / 'tool-source'
    (primary / 'tooling/scripts').mkdir(parents=True)
    for name in ('external-skills.sh', 'external_skills.py'):
        shutil.copy2(ROOT / 'tooling/scripts' / name, primary / 'tooling/scripts' / name)
    git(primary, 'init', '-q')
    git(primary, 'add', '.')
    git(primary, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.test', 'commit', '-qm', 'fixture')
    worktree = root / 'tool-worktree'
    git(primary, 'worktree', 'add', '--detach', str(worktree), 'HEAD')
    (primary / 'skills').mkdir()
    before = snapshot(primary)
    run('install', '--apply', target=primary / 'skills', cli=worktree / 'tooling/scripts/external-skills.sh', ok=False)
    assert before == snapshot(primary)

print('All external skill management scenarios passed.')
PY
