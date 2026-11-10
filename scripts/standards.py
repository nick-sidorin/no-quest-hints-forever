#!/usr/bin/env python3
"""Copy reviewed shared standards from local Git and verify them offline (Python 3.9+)."""
import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

REPOSITORY = "https://github.com/nick-sidorin/wow-addon-standards"
DOCUMENTS = ("AGENTS.md", "FIELD_NOTES.md")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def git(source, *args):
    return subprocess.check_output(["git", "-C", str(source), *args], stderr=subprocess.PIPE)


def validate(lock):
    if not isinstance(lock, dict) or lock.get("repository") != REPOSITORY:
        raise ValueError("Unexpected source repository")
    if not re.fullmatch(r"[0-9a-f]{40}", str(lock.get("commit", ""))):
        raise ValueError("Use a full reviewed commit SHA")
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", str(lock.get("version", ""))):
        raise ValueError("Invalid standards version")
    hashes = lock.get("files")
    if not isinstance(hashes, dict) or set(hashes) != set(DOCUMENTS):
        raise ValueError("Unexpected document inventory")
    if any(not re.fullmatch(r"[0-9a-f]{64}", str(hashes[name])) for name in DOCUMENTS):
        raise ValueError("Invalid document hash")


def check(target):
    directory = target / "docs" / "standards"
    lock = json.loads((directory / "standards.lock.json").read_text(encoding="utf-8"))
    validate(lock)
    for name in DOCUMENTS:
        if digest((directory / name).read_bytes()) != lock["files"][name]:
            raise ValueError("Vendored document differs from lock: " + name)
    print("Standards {} at {}: verified offline".format(lock["version"], lock["commit"]))


def sync(source, commit, target):
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Use a full reviewed commit SHA, not a branch or moving tag")
    remote = git(source, "remote", "get-url", "origin").decode().strip().removesuffix(".git").rstrip("/")
    if remote != REPOSITORY:
        raise ValueError("Source origin must be " + REPOSITORY)
    if git(source, "rev-parse", "--verify", commit + "^{commit}").decode().strip() != commit:
        raise ValueError("Source commit mismatch")
    version = git(source, "show", commit + ":VERSION").decode("utf-8").strip()
    contents = {name: git(source, "show", commit + ":" + name) for name in DOCUMENTS}
    if any(not content.decode("utf-8").strip() for content in contents.values()):
        raise ValueError("Empty document")
    lock = {"repository": REPOSITORY, "commit": commit, "version": version,
            "files": {name: digest(content) for name, content in contents.items()}}
    validate(lock)
    directory = target / "docs" / "standards"
    directory.mkdir(parents=True, exist_ok=True)
    for name, content in contents.items():
        (directory / name).write_bytes(content)
    (directory / "standards.lock.json").write_text(json.dumps(lock, indent=2) + "\n", encoding="utf-8")
    check(target)
    print("Review the diff in a PR; root agent instructions and runtime files were not changed.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    checker = commands.add_parser("check", help="verify copied documents without network access")
    checker.add_argument("--target", type=Path, default=Path.cwd())
    updater = commands.add_parser("sync", help="copy documents from a reviewed local Git commit")
    updater.add_argument("--source", type=Path, required=True)
    updater.add_argument("--commit", required=True)
    updater.add_argument("--target", type=Path, default=Path.cwd())
    args = parser.parse_args()
    if args.command == "check":
        check(args.target)
    else:
        sync(args.source, args.commit, args.target)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print("STANDARDS CHECK FAILED: " + str(error), file=sys.stderr)
        sys.exit(1)
