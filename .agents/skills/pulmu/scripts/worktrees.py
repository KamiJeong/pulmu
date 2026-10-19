#!/usr/bin/env python3
"""Prepare isolated issue worktrees; no scheduling, merging, or automatic deletion."""

import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys


def git(*args, cwd=None):
    return subprocess.check_output(["git", *args], cwd=cwd, text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    create = sub.add_parser("create")
    create.add_argument("--path", required=True)
    create.add_argument("--base", required=True)
    create.add_argument("--base-ref", required=True)
    create.add_argument("ignite_args", nargs=argparse.REMAINDER)
    sub.add_parser("list")
    args = parser.parse_args()
    if args.command == "list":
        records = []
        raw = subprocess.check_output(["git", "worktree", "list", "--porcelain", "-z"])
        for block in raw.split(b"\0\0"):
            fields = dict(item.decode().split(" ", 1) for item in block.split(b"\0") if b" " in item)
            if "worktree" not in fields:
                continue
            record = {"path": fields["worktree"], "branch": fields.get("branch"), "run": None}
            try:
                metadata = Path(git("rev-parse", "--absolute-git-dir", cwd=fields["worktree"]))
                state_file = metadata / "pulmu/run.json"
                if state_file.is_symlink():
                    raise ValueError("symlinked run record")
                if state_file.is_file():
                    state = json.loads(state_file.read_text())
                    record["run"] = {"id": state["runId"], "status": state["status"], "stage": state["stage"]["current"]}
            except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError):
                record["error"] = "worktree state unavailable or malformed"
            records.append(record)
        print(json.dumps(records, ensure_ascii=False, indent=2))
        return 0
    source = Path(git("rev-parse", "--show-toplevel")).resolve()
    target = Path(args.path).expanduser().absolute()
    if target.exists() or target.is_symlink():
        parser.error("worktree destination already exists; choose a new path")
    target = target.resolve()
    if target == source or source in target.parents:
        parser.error("worktree destination must be outside the source working tree")
    common = Path(git("rev-parse", "--path-format=absolute", "--git-common-dir"))
    lock = common / "pulmu-worktrees.lock"
    fd = os.open(lock, os.O_RDWR | os.O_CREAT | getattr(os, "O_NOFOLLOW", 0), 0o600)
    with os.fdopen(fd, "w") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        registered = subprocess.check_output(["git", "worktree", "list", "--porcelain", "-z"])
        roots = [Path(item[len(b"worktree "):].decode()).resolve()
                 for item in registered.split(b"\0") if item.startswith(b"worktree ")]
        roots.append(common.resolve())
        if any(target == root or root in target.parents for root in roots):
            parser.error("worktree destination must be outside every registered worktree and Git metadata directory")
        # Resolve the start commit before creation. Parent edits and run state stay put.
        commit = git("rev-parse", "--verify", f"{args.base_ref}^{{commit}}")
        target.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "worktree", "add", "--detach", str(target), commit], check=True)
        forwarded = args.ignite_args[1:] if args.ignite_args[:1] == ["--"] else args.ignite_args
        script = Path(__file__).resolve().with_name("ignite.sh")
        result = subprocess.run(["bash", str(script), "--base", args.base, *forwarded], cwd=target)
        if result.returncode:
            print(f"Worktree retained after initialization failure: {target}", file=sys.stderr)
            return result.returncode
    print(f"PULMU_WORKTREE={target}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"worktree preparation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
