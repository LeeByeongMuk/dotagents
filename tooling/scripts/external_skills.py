#!/usr/bin/env python3
"""Explicit pinned Git skill links. Never execute upstream checkout contents."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import signal
import subprocess
import sys
import tempfile
import unicodedata
from urllib.parse import urlparse, unquote

if sys.version_info < (3, 11):
    sys.exit("error: external-skills requires Python 3.11 or newer (stdlib tomllib)")
import tomllib

ROOT = Path(__file__).resolve().parents[2]
ID = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")
REVISION = re.compile(r"[0-9a-f]{40}\Z")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_toml(path):
    require(path.is_file() and not path.is_symlink(), "registry or lock is missing or linked")
    with path.open("rb") as stream:
        return tomllib.load(stream)


def keyed(entries):
    require(isinstance(entries, list), "registry entries must be a list")
    result = {}
    for entry in entries:
        require(isinstance(entry, dict), "registry entry must be a table")
        name = entry.get("id", "")
        require(isinstance(name, str) and ID.fullmatch(name), "invalid registry ID")
        require(name not in result, "duplicate registry ID")
        result[name] = entry
    return result


def safe_relative(value):
    require(isinstance(value, str) and value and "\\" not in value,
            "invalid source-relative path")
    parts = value.split("/")
    require(not value.startswith("/") and all(part not in ("", ".", "..") for part in parts)
            and not any(ord(char) < 32 for char in value)
            and all(part.casefold() != ".git" for part in parts), "unsafe source-relative path")
    return PurePosixPath(value)


def guarded(path):
    """Reject every existing symlink component, without resolving through it."""
    path = Path(path).expanduser()
    require(".." not in path.parts, "parent traversal is not allowed")
    path = Path(os.path.abspath(path))
    require(not any(ord(char) < 32 for char in str(path)), "unsafe path characters")
    for cursor in [*reversed(path.parents), path]:
        require(not cursor.is_symlink(), "symlink path component refused: " + str(cursor))
    return path


def selected_root(value):
    path = guarded(value)
    require(path.is_dir(), "destination and state directories must already exist")
    home = Path.home().resolve()
    require(path != Path("/") and path != home, "root and home are not skill directories")
    require(path != ROOT and ROOT not in path.parents and path not in ROOT.parents,
            "dotagents source checkout and its ancestors are protected")
    source_common = common_directory(ROOT)
    require(not source_common or common_directory(path) != source_common,
            "dotagents source repository and linked worktrees are protected")
    require(not any(part.casefold() == ".git" for part in path.parts), "Git metadata is protected")
    return path


def source_url(value, check_local=True):
    require(isinstance(value, str), "source URL is required")
    if re.fullmatch(r"https://github\.com/[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9][A-Za-z0-9_.-]*", value):
        return value
    parsed = urlparse(value)
    if parsed.scheme == "file" and not parsed.netloc and not parsed.query and not parsed.fragment:
        local = Path(unquote(parsed.path))
        require(local.is_absolute() and ".." not in local.parts, "local source must be absolute")
        if check_local:
            local = guarded(local)
            require(local.is_dir(), "local source must be an existing Git directory")
        return local.as_uri()
    raise ValueError("only public GitHub HTTPS or local file source URLs are supported")


def git(repo, *args, check=True):
    # No global credential helpers, hooks, user filters, URL rewrites or init templates.
    env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    env.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull, GIT_TERMINAL_PROMPT="0")
    command = ["git", "-c", "core.hooksPath=" + os.devnull, "-c", "core.fsmonitor=false",
               "-c", "protocol.allow=never", "-c", "protocol.https.allow=always",
               "-c", "protocol.file.allow=always"]
    if repo is not None:
        command += ["--git-dir=" + str(repo)]
    run = subprocess.run(command + list(args), env=env, capture_output=True)
    if not check and run.returncode != 0:
        return None
    require(run.returncode == 0, "Git operation failed: " + args[0] + " (details suppressed)")
    return run.stdout


def common_directory(path):
    result = git(None, "-C", str(path), "rev-parse", "--git-common-dir", check=False)
    if result is None:
        return None
    common = Path(result.decode().strip())
    return (common if common.is_absolute() else path / common).resolve()


def internal_link(path, root):
    try:
        resolved = path.resolve(strict=True)
    except FileNotFoundError:
        # Preserve safe links to optional build outputs, but strict resolution
        # above still rejects cycles on both Python 3.11 and newer runtimes.
        resolved = path.resolve()
    require(resolved.is_relative_to(root), "upstream symlink escapes its repository")


def digest_tree(root):
    require(root.is_dir() and not root.is_symlink(), "managed payload is missing or linked")
    digest = hashlib.sha256()
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            internal_link(path, root)
            value = b"link\0" + os.fsencode(os.readlink(path))
        elif path.is_file():
            value = b"file\0" + str(path.stat().st_mode & 0o777).encode() + b"\0" + path.read_bytes()
        elif path.is_dir():
            value = b"directory"
        else:
            raise ValueError("managed payload contains a special file")
        digest.update(relative.encode() + b"\0" + value + b"\0")
    return digest.hexdigest()


def materialize(repo, revision, payload):
    tree = git(repo, "ls-tree", "-rz", revision)
    entries = []
    names = {}
    for row in tree.split(b"\0"):
        if not row:
            continue
        header, raw_path = row.split(b"\t", 1)
        mode, kind, oid = header.decode().split()
        path = raw_path.decode("utf-8")
        safe_relative(path)
        for prefix in PurePosixPath(path).parents:
            if str(prefix) != ".":
                spelling = str(prefix)
                normalized = unicodedata.normalize("NFD", spelling).casefold()
                require(names.get(normalized, spelling) == spelling, "source has colliding file names")
                names[normalized] = spelling
        normalized = unicodedata.normalize("NFD", path).casefold()
        require(normalized not in names, "source has colliding file names")
        names[normalized] = path
        require(kind == "blob" and mode in ("100644", "100755", "120000"),
                "submodules and special Git entries are unsupported")
        entries.append((path, mode, oid))
    # Raw object reads avoid checkout filters, archive export rules, and hooks.
    require(entries, "pinned source tree is empty")
    if entries:
        # Batch input uses only object IDs from ls-tree, never shell interpolation.
        env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        env.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
        result = subprocess.run(["git", "--git-dir=" + str(repo), "cat-file", "--batch"],
                                input=("\n".join(row[2] for row in entries) + "\n").encode(),
                                capture_output=True, env=env)
        require(result.returncode == 0, "could not read pinned Git blobs")
        objects = result.stdout
    stream = io.BytesIO(objects)
    payload.mkdir()
    links = []
    for path, mode, oid in entries:
        header = stream.readline().decode().split()
        require(len(header) == 3 and header[:2] == [oid, "blob"], "unexpected Git blob")
        size = int(header[2])
        data = stream.read(size)
        require(len(data) == size and stream.read(1) == b"\n", "incomplete Git blob")
        target = payload / path
        target.parent.mkdir(parents=True, exist_ok=True)
        if mode == "120000":
            link = data.decode("utf-8")
            require(link and not os.path.isabs(link) and "\\" not in link
                    and not any(ord(char) < 32 or ord(char) == 127 for char in link),
                    "unsafe upstream symlink")
            links.append((target, link))
        else:
            target.write_bytes(data)
            target.chmod(0o755 if mode == "100755" else 0o644)
    # Create links last so writing regular files never traverses upstream links.
    for target, link in links:
        target.symlink_to(link)
    for target, _ in links:
        internal_link(target, payload)


def cache_path(state, source, revision):
    require(ID.fullmatch(source) and REVISION.fullmatch(revision), "invalid cached source identity")
    return guarded(state / "checkouts" / source / revision)


def verify_cache(cache, source, url, revision, expected_digest=None):
    receipt_path = guarded(cache / "receipt.json")
    receipt = json.loads(receipt_path.read_text())
    require(isinstance(receipt, dict), "invalid cache receipt")
    require(receipt.get("source_id") == source and receipt.get("url") == url
            and receipt.get("revision") == revision, "cache provenance conflict")
    require(git(guarded(cache / "repository.git"), "rev-parse", "FETCH_HEAD^{commit}").decode().strip()
            == revision, "cached commit does not match the pin")
    digest = digest_tree(guarded(cache / "payload"))
    require(digest == receipt.get("digest") and (expected_digest is None or digest == expected_digest),
            "managed payload was modified; preserved")
    return digest


def fetch_cache(state, source, url, revision):
    cache = cache_path(state, source, revision)
    if cache.exists():
        return cache, verify_cache(cache, source, url, revision)
    parent = guarded(cache.parent)
    parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".fetch-", dir=parent) as temporary:
        staging = Path(temporary)
        repo = staging / "repository.git"
        git(None, "init", "--bare", "--template=", str(repo))
        git(repo, "fetch", "--depth=1", "--no-tags", url, revision)
        require(git(repo, "rev-parse", "FETCH_HEAD^{commit}").decode().strip() == revision,
                "fetched commit does not match the pin")
        materialize(repo, revision, staging / "payload")
        digest = digest_tree(staging / "payload")
        (staging / "receipt.json").write_text(json.dumps(dict(source_id=source, url=url,
                                                             revision=revision, digest=digest), indent=2) + "\n")
        # Rename a complete immutable revision into the cache, then let the temporary
        # directory context remove only a newly recreated empty staging directory.
        staging.rename(cache)
        staging.mkdir()
    return cache, digest


def write_record(path, record):
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", prefix=".record-", dir=path.parent, delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(record, stream, indent=2)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("list", "inspect", "plan", "install", "update", "remove"))
    parser.add_argument("skill", nargs="?")
    parser.add_argument("--host", choices=("claude", "codex", "gemini"))
    parser.add_argument("--dest", help="existing host skills directory; no automatic host path selection")
    parser.add_argument("--state-dir", help="existing isolated state/cache directory")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    require(not args.apply or args.action in ("install", "update", "remove"), "--apply requires a mutation command")
    # Removal owns actual installed state and remains available after an upstream
    # declaration is retired or the source becomes unavailable.
    skills, sources = {}, {}
    if args.action != "remove":
        skills = keyed(read_toml(Path(os.environ.get("DOTAGENTS_SKILLS_FILE", ROOT / "agents/registry/skills.toml")))["skills"])
        sources = keyed(read_toml(Path(os.environ.get("DOTAGENTS_SOURCES_FILE", ROOT / "agents/registry/sources.lock")))["sources"])
    if args.action == "list":
        require(not args.skill and not any((args.host, args.dest, args.state_dir)), "list does not take a target")
        for name, entry in skills.items():
            if entry.get("kind") == "external":
                print(name + "\t" + entry.get("source_id", "") + "\t" + ",".join(entry.get("hosts", [])))
        return
    require(isinstance(args.skill, str) and ID.fullmatch(args.skill), "select a valid skill ID")
    if args.action != "remove":
        require(args.skill in skills and skills[args.skill].get("kind") == "external", "select a registered external skill")
        skill = skills[args.skill]
        source = skill.get("source_id", "")
        require(source in sources, "external skill source is not locked")
        path = safe_relative(skill.get("path"))
        require(path.name == "SKILL.md" and len(path.parts) > 1, "skill must have a repository-relative directory")
        revision = sources[source].get("revision", "")
        require(isinstance(revision, str) and REVISION.fullmatch(revision), "source must pin a full lowercase Git commit")
        url = source_url(sources[source].get("url"))
        print(f"desired: {args.skill} source={source} revision={revision} path={path}")
        print("source: " + url)
    if args.action == "inspect" and not any((args.host, args.dest, args.state_dir)):
        print("actual: not inspected; select --host, --dest and --state-dir")
        return
    require(args.host and (args.action == "remove" or args.host in skill.get("hosts", [])), "choose a supported --host")
    require(args.dest and args.state_dir, "--dest and --state-dir are required")
    dest, state = selected_root(args.dest), selected_root(args.state_dir)
    require(dest != state and not dest.is_relative_to(state) and not state.is_relative_to(dest),
            "destination and state must not overlap")
    target = dest / args.skill
    records = guarded(state / "installs")
    key = hashlib.sha256((str(dest) + "\0" + args.skill).encode()).hexdigest()
    record_path = guarded(records / (key + ".json"))
    record_bytes = record_path.read_bytes() if record_path.exists() else None
    record = json.loads(record_bytes) if record_bytes is not None else None
    require(record is None or (isinstance(record, dict) and record), "invalid install record")
    if record:
        require(record.get("version") == 1 and record.get("skill") == args.skill
                and record.get("host") == args.host and record.get("destination") == str(target),
                "install record conflicts with the selected target or host")
        old_cache = cache_path(state, record["source_id"], record["revision"])
        old_path = safe_relative(record["path"])
        expected = old_cache / "payload" / old_path.parent
        require(record.get("target") == str(expected), "unsafe install record target")
        verify_cache(old_cache, record["source_id"], source_url(record["url"], check_local=False), record["revision"], record["digest"])
        require(not os.path.lexists(target) or (target.is_symlink() and os.readlink(target) == str(expected)),
                "managed target was replaced; preserved")
        status = "linked" if target.is_symlink() else "missing"
        print(f"actual: managed status={status} host={args.host} revision={record['revision']} target={target}")
    else:
        require(not os.path.lexists(target), "unmanaged target exists; preserved")
        print("actual: not installed at " + str(target))
    if args.action == "inspect":
        return
    if args.action == "remove":
        require(record is not None, "target is not owned by this state directory")
    if args.action == "update":
        require(record is not None, "update requires an owned install; use install first")
    if args.action == "install" and record:
        require(all(record.get(key) == value for key, value in dict(source_id=source, revision=revision,
                    path=str(path), url=url).items()), "pinned source changed; use update")
    operation = "remove" if args.action == "remove" else ("update" if record else "install")
    print(f"plan: {operation} {target} for {args.host}; only selected skill link and provenance change")
    if not args.apply:
        print("preview only: no fetch or writes; use install/update/remove with --apply")
        return
    lock = guarded(state / ".external-skills.lock")
    lock.mkdir()  # Refuse concurrent mutations using this state directory.
    previous = os.readlink(target) if target.is_symlink() else None
    changed = False
    new_target = None
    new_record = None
    publication_started = False

    def unchanged():
        require((record_path.read_bytes() if record_path.exists() else None) == record_bytes,
                "install record changed during operation; preserved")
        require((not os.path.lexists(target)) if previous is None else
                (target.is_symlink() and os.readlink(target) == previous),
                "target changed during operation; preserved")
        if record:
            verify_cache(old_cache, record["source_id"], source_url(record["url"], check_local=False),
                         record["revision"], record["digest"])

    def provenance_committed():
        if not publication_started:
            return False
        if args.action == "remove":
            return not os.path.lexists(record_path)
        if record_path.is_symlink() or not record_path.is_file():
            return False
        return json.loads(record_path.read_bytes()) == new_record

    try:
        records.mkdir(exist_ok=True)
        if args.action == "remove":
            unchanged()
            if previous is not None:
                changed = True
                target.unlink()
            publication_started = True
            record_path.unlink()
        else:
            cache, digest = fetch_cache(state, source, url, revision)
            skill_file = guarded(cache / "payload" / path)
            require(skill_file.is_file(), "pinned skill path is missing")
            new_target = str(skill_file.parent)
            new_record = dict(version=1, skill=args.skill, host=args.host, destination=str(target),
                              source_id=source, revision=revision, path=str(path), url=url,
                              target=new_target, digest=digest)
            unchanged()
            changed = True
            if previous is None:
                target.symlink_to(new_target)
            else:
                with tempfile.TemporaryDirectory(prefix=".link-", dir=dest) as temporary:
                    link = Path(temporary) / args.skill
                    link.symlink_to(new_target)
                    os.replace(link, target)
            publication_started = True
            write_record(record_path, new_record)
        changed = False
        print("applied: " + operation + "; cached revisions retained; no upstream code executed")
    except BaseException:
        # The filesystem record is the commit boundary, including a syscall that
        # completed before raising or a signal before the next Python assignment.
        # Rolling back just the link after this boundary would split the pair.
        if provenance_committed():
            print("committed: " + operation + "; provenance published before failure; link rollback skipped", file=sys.stderr)
        elif changed:
            # Restore only this operation's link. A concurrent replacement is
            # user-owned and must survive even when record publication fails.
            ours = target.is_symlink() and os.readlink(target) == new_target
            if ours or (args.action == "remove" and not os.path.lexists(target)):
                if ours:
                    target.unlink()
                if previous is not None:
                    target.symlink_to(previous)
        raise
    finally:
        lock.rmdir()


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(InterruptedError("terminated")))
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError, RuntimeError, tomllib.TOMLDecodeError, KeyboardInterrupt) as error:
        sys.exit("error: " + str(error))
