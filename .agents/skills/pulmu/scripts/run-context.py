#!/usr/bin/env python3
"""Deterministic Pulmu Run Context storage.

The state lives under the resolved Git metadata directory. This module intentionally
uses only the Python standard library so it can be installed with the Pulmu skill.
"""

from __future__ import annotations

import argparse
import datetime as dt
import fcntl
import json
import os
import re
import secrets
import stat
import subprocess
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator


SCHEMA_VERSION = 1
WORKFLOW = "pulmu"
VERSION_FILE = Path(__file__).resolve().parent.parent / "VERSION"
DEFAULT_PULMU_VERSION = VERSION_FILE.read_text(encoding="utf-8").strip()
STATUSES = {"running", "completed", "failed", "interrupted"}
STAGES = {"ignite", "inspect", "shape", "hammer", "quench", "hone", "ship"}
STAGE_ORDER = ("ignite", "inspect", "shape", "hammer", "quench", "hone", "ship")
STAGE_STATUSES = {"in_progress", "completed", "failed", "interrupted"}
RETRY_LIMITS = {"quench": 3, "hone": 2}
TASK_TYPES = {"feature", "bugfix", "refactor", "docs", "test", "chore"}
FORGES = {"quick", "standard", "full"}
RISKS = {"low", "medium", "high"}
AGENT_RE = re.compile(r"^pulmu_[a-z0-9_]+$")
RUN_ID_RE = re.compile(r"^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{12}$")
ERROR_CODE_RE = re.compile(r"^[A-Z][A-Z0-9_]{0,63}$")
AREA_RE = re.compile(r"^[a-z][a-z0-9-]*$")
PR_URL_RE = re.compile(r"^https://[^\s/]+(?:/[^\s/]+){2}/pull/([0-9]+)$")
REVIEW_ROLES = {
    "pulmu_reviewer", "pulmu_test_reviewer", "pulmu_security_reviewer",
    "pulmu_compat_reviewer", "pulmu_design_reviewer",
}


class ContextError(RuntimeError):
    pass


def die(message: str) -> None:
    print(f"✗ {message}", file=sys.stderr)
    raise SystemExit(1)


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def next_timestamp(state: dict[str, Any]) -> str:
    now = dt.datetime.now(dt.timezone.utc)
    previous = dt.datetime.fromisoformat(state["updatedAt"][:-1] + "+00:00")
    if now <= previous:
        now = previous + dt.timedelta(microseconds=1)
    return now.isoformat(timespec="microseconds").replace("+00:00", "Z")


def new_run_id() -> str:
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return f"{stamp}-{secrets.token_hex(6)}"


SECRET_PATTERNS = (
    re.compile(r"(?i)\b(bearer)\s+[A-Za-z0-9._~+/=-]{8,}"),
    re.compile(r"\b(?:github_pat_|gh[pousr]_|sk-)[A-Za-z0-9_-]{8,}"),
    re.compile(r"\bAKIA[0-9A-Z]{12,}\b"),
    re.compile(r"(?i)\b([A-Za-z0-9_-]*(?:token|secret|password|passwd|api[_-]?key)[A-Za-z0-9_-]*)\s*[:=]\s*[^\s,;]+"),
    re.compile(r"(?i)https?://[^\s/:]+:[^\s/@]+@"),
    re.compile(r"(?i)-----BEGIN [^-]*PRIVATE KEY-----.*?-----END [^-]*PRIVATE KEY-----"),
)


def concise(value: str, limit: int) -> str:
    value = " ".join(value.replace("\x00", "").split())
    for pattern in SECRET_PATTERNS:
        value = pattern.sub(lambda match: f"{match.group(1)} [REDACTED]" if match.lastindex else "[REDACTED]", value)
    if len(value) > limit:
        value = value[: limit - 1].rstrip() + "…"
    return value


def git_dir() -> Path:
    try:
        raw = subprocess.run(
            ["git", "rev-parse", "--path-format=absolute", "--git-dir"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except (FileNotFoundError, subprocess.CalledProcessError):
        raise ContextError("not inside a Git repository")
    path = Path(raw)
    if not path.is_dir():
        raise ContextError("resolved Git metadata directory does not exist")
    return path


class Store:
    def __init__(self) -> None:
        self.root = git_dir() / "pulmu"
        self.path = self.root / "run.json"
        self.history = self.root / "runs"
        self.lock_path = self.root / "run.lock"

    @staticmethod
    def _ensure_real_directory(path: Path) -> None:
        if path.exists() or path.is_symlink():
            info = path.lstat()
            if stat.S_ISLNK(info.st_mode) or not stat.S_ISDIR(info.st_mode):
                raise ContextError(f"Run Context storage is not a real directory: {path}")
        else:
            path.mkdir(mode=0o700)
        os.chmod(path, 0o700)

    def prepare(self) -> None:
        self._ensure_real_directory(self.root)
        self._ensure_real_directory(self.history)
        if self.path.is_symlink():
            raise ContextError(f"Run Context file must not be a symlink: {self.path}")
        if self.lock_path.is_symlink():
            raise ContextError(f"Run Context lock must not be a symlink: {self.lock_path}")

    @contextmanager
    def lock(self, *, exclusive: bool = True) -> Iterator[None]:
        self.prepare()
        flags = os.O_RDWR | os.O_CREAT
        if hasattr(os, "O_NOFOLLOW"):
            flags |= os.O_NOFOLLOW
        fd = os.open(self.lock_path, flags, 0o600)
        try:
            os.fchmod(fd, 0o600)
            fcntl.flock(fd, fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH)
            yield
        finally:
            fcntl.flock(fd, fcntl.LOCK_UN)
            os.close(fd)

    def read(self) -> dict[str, Any] | None:
        if not self.path.exists() and not self.path.is_symlink():
            return None
        flags = os.O_RDONLY
        if hasattr(os, "O_NOFOLLOW"):
            flags |= os.O_NOFOLLOW
        try:
            fd = os.open(self.path, flags)
            if not stat.S_ISREG(os.fstat(fd).st_mode):
                os.close(fd)
                raise ContextError("Run Context is not a regular file")
            with os.fdopen(fd, "r", encoding="utf-8") as handle:
                state = json.load(handle)
        except (OSError, UnicodeError, json.JSONDecodeError) as exc:
            raise ContextError(f"Run Context is malformed: {exc}") from exc
        validate_state(state)
        return state

    def write(self, state: dict[str, Any]) -> None:
        validate_state(state)
        fd, temp_name = tempfile.mkstemp(prefix=".run.", suffix=".json", dir=self.root)
        temp = Path(temp_name)
        try:
            os.fchmod(fd, 0o600)
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                json.dump(state, handle, ensure_ascii=False, indent=2, sort_keys=False)
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temp, self.path)
            os.chmod(self.path, 0o600)
            directory_fd = os.open(self.root, os.O_RDONLY)
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
        finally:
            if temp.exists():
                temp.unlink()

    def snapshot(self, state: dict[str, Any], *, suffix: str | None = None) -> Path:
        filename = state["runId"] if suffix is None else f"{state['runId']}-{suffix}"
        destination = self.history / f"{filename}.json"
        if destination.exists() or destination.is_symlink():
            info = destination.lstat()
            if stat.S_ISLNK(info.st_mode) or not stat.S_ISREG(info.st_mode):
                raise ContextError(f"Run Context history target is unsafe: {destination}")
            return destination
        fd, temp_name = tempfile.mkstemp(prefix=".history.", suffix=".json", dir=self.history)
        temp = Path(temp_name)
        try:
            os.fchmod(fd, 0o600)
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                json.dump(state, handle, ensure_ascii=False, indent=2)
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
            try:
                os.link(temp, destination)
            except FileExistsError:
                info = destination.lstat()
                if stat.S_ISLNK(info.st_mode) or not stat.S_ISREG(info.st_mode):
                    raise ContextError(f"Run Context history target is unsafe: {destination}")
            os.chmod(destination, 0o600, follow_symlinks=False)
            return destination
        finally:
            if temp.exists():
                temp.unlink()

    def quarantine(self) -> Path:
        stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        destination = self.history / f"corrupt-{stamp}-{secrets.token_hex(4)}.json"
        if self.path.is_symlink() or not self.path.is_file():
            raise ContextError("unsafe malformed Run Context cannot be quarantined automatically")
        os.replace(self.path, destination)
        os.chmod(destination, 0o600)
        return destination


def expect(condition: bool, message: str) -> None:
    if not condition:
        raise ContextError(message)


def is_iso_timestamp(value: Any) -> bool:
    if not isinstance(value, str) or not value.endswith("Z"):
        return False
    try:
        dt.datetime.fromisoformat(value[:-1] + "+00:00")
        return True
    except ValueError:
        return False


def validate_state(state: Any) -> None:
    expect(isinstance(state, dict), "Run Context root must be an object")
    required = {
        "schemaVersion", "workflow", "pulmuVersion", "runId", "status", "task", "forge",
        "risk", "areas", "pattern", "stage", "git", "agents", "retries", "startedAt",
        "updatedAt", "completedAt", "interruptedAt", "pr", "error",
    }
    expect(set(state) == required, "Run Context fields do not match schema version 1")
    expect(state["schemaVersion"] == SCHEMA_VERSION, "unsupported Run Context schemaVersion")
    expect(state["workflow"] == WORKFLOW, "Run Context workflow must be pulmu")
    expect(isinstance(state["pulmuVersion"], str) and 0 < len(state["pulmuVersion"]) <= 32, "invalid Pulmu version")
    expect(isinstance(state["runId"], str) and bool(RUN_ID_RE.fullmatch(state["runId"])), "invalid Run Context runId")
    expect(isinstance(state["status"], str) and state["status"] in STATUSES, "invalid Run Context status")

    task = state["task"]
    expect(isinstance(task, dict) and set(task) == {"prompt", "type"}, "invalid Run Context task")
    expect(isinstance(task["prompt"], str) and 0 < len(task["prompt"]) <= 2000, "invalid Run Context task prompt")
    expect(isinstance(task["type"], str) and task["type"] in TASK_TYPES, "invalid Run Context task type")
    expect(state["forge"] is None or (isinstance(state["forge"], str) and state["forge"] in FORGES), "invalid Run Context forge")
    expect(state["risk"] is None or (isinstance(state["risk"], str) and state["risk"] in RISKS), "invalid Run Context risk")
    expect(isinstance(state["areas"], list) and len(state["areas"]) <= 3, "invalid Run Context areas")
    expect(all(isinstance(area, str) and AREA_RE.fullmatch(area) for area in state["areas"]), "invalid Run Context area")
    expect(len(set(state["areas"])) == len(state["areas"]), "duplicate Run Context area")
    expect(isinstance(state["pattern"], bool), "invalid Run Context Pattern flag")

    stage = state["stage"]
    expect(isinstance(stage, dict) and set(stage) == {"current", "status"}, "invalid Run Context stage")
    expect(isinstance(stage["current"], str) and isinstance(stage["status"], str)
           and stage["current"] in STAGES and stage["status"] in STAGE_STATUSES, "invalid Run Context stage value")
    git = state["git"]
    expect(isinstance(git, dict) and set(git) == {"baseBranch", "branch", "commit"}, "invalid Run Context git")
    expect(all(value is None or (isinstance(value, str) and 0 < len(value) <= 512) for value in git.values()), "invalid Run Context Git metadata")
    agents = state["agents"]
    expect(isinstance(agents, dict) and set(agents) == {"active"}, "invalid Run Context agents")
    expect(isinstance(agents["active"], list) and len(agents["active"]) <= 16, "invalid active agents")
    expect(all(isinstance(agent, str) and AGENT_RE.fullmatch(agent) for agent in agents["active"]), "invalid active agent")
    expect(len(set(agents["active"])) == len(agents["active"]), "duplicate active agent")
    retries = state["retries"]
    expect(isinstance(retries, dict) and set(retries) == {"quench", "hone"}, "invalid Run Context retries")
    expect(all(isinstance(retries[name], int) and not isinstance(retries[name], bool)
               and 0 <= retries[name] <= RETRY_LIMITS[name] for name in RETRY_LIMITS), "invalid retry count")
    expect(is_iso_timestamp(state["startedAt"]) and is_iso_timestamp(state["updatedAt"]), "invalid Run Context timestamp")
    for key in ("completedAt", "interruptedAt"):
        expect(state[key] is None or is_iso_timestamp(state[key]), f"invalid {key}")
    started = dt.datetime.fromisoformat(state["startedAt"][:-1] + "+00:00")
    updated = dt.datetime.fromisoformat(state["updatedAt"][:-1] + "+00:00")
    expect(started <= updated, "Run Context updatedAt precedes startedAt")
    if state["status"] == "running":
        expect(state["stage"]["status"] == "in_progress", "running run requires an in-progress stage")
        expect(state["completedAt"] is None and state["interruptedAt"] is None, "running run has a terminal timestamp")
        expect(state["pr"] is None and state["error"] is None, "running run has terminal result data")
    elif state["status"] == "completed":
        expect(state["stage"] == {"current": "ship", "status": "completed"}, "completed run must complete Ship")
        expect(state["completedAt"] == state["updatedAt"], "completed run requires a current completedAt")
        expect(state["interruptedAt"] is None and state["error"] is None, "completed run has contradictory terminal data")
        expect(state["git"]["commit"] is not None, "completed run requires a commit")
    elif state["status"] == "failed":
        expect(state["stage"]["status"] == "failed", "failed run requires a failed stage")
        expect(state["completedAt"] is None and state["interruptedAt"] is None and state["pr"] is None, "failed run has contradictory terminal data")
        expect(state["error"] is not None, "failed run requires a concise error")
    else:
        expect(state["stage"]["status"] == "interrupted", "interrupted run requires an interrupted stage")
        expect(state["interruptedAt"] == state["updatedAt"], "interrupted run requires a current interruptedAt")
        expect(state["completedAt"] is None and state["pr"] is None, "interrupted run has contradictory terminal data")
    pr = state["pr"]
    if pr is not None:
        expect(isinstance(pr, dict) and set(pr) == {"number", "url"}, "invalid Run Context PR")
        number, url = pr.get("number"), pr.get("url")
        match = PR_URL_RE.fullmatch(url) if isinstance(url, str) else None
        expect(isinstance(number, int) and not isinstance(number, bool) and number > 0 and match is not None,
               "invalid Run Context PR value")
        expect(int(match.group(1)) == pr["number"], "Run Context PR number does not match URL")
    error = state["error"]
    if error is not None:
        expect(isinstance(error, dict) and set(error) == {"code", "message"}, "invalid Run Context error")
        expect(isinstance(error["code"], str) and ERROR_CODE_RE.fullmatch(error["code"]), "invalid error code")
        expect(isinstance(error["message"], str) and 0 < len(error["message"]) <= 500, "invalid error message")


def require_running(state: dict[str, Any], expected_run_id: str | None) -> None:
    if expected_run_id is not None:
        expect(state["runId"] == expected_run_id, "Run Context runId changed; refusing stale update")
    expect(state["status"] == "running", f"Run Context is terminal ({state['status']})")


def read_required(store: Store) -> dict[str, Any]:
    state = store.read()
    expect(state is not None, "Run Context does not exist; run Ignite first")
    return state


def touch(state: dict[str, Any]) -> None:
    state["updatedAt"] = next_timestamp(state)


def atomic_text(path: Path, value: str) -> None:
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temp = Path(temp_name)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(value)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp, path)
    finally:
        if temp.exists():
            temp.unlink()


def atomic_copy(source: Path, destination: Path) -> None:
    fd, temp_name = tempfile.mkstemp(prefix=f".{destination.name}.", dir=destination.parent)
    temp = Path(temp_name)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "wb") as handle:
            handle.write(source.read_bytes())
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp, destination)
    finally:
        if temp.exists():
            temp.unlink()


def git_candidate_tree(store: Store) -> str:
    if Path(".gitmodules").is_file():
        result = subprocess.run(
            ["git", "submodule", "foreach", "--quiet", "--recursive",
             'test -z "$(git status --porcelain --untracked-files=all)"'],
            capture_output=True,
        )
        expect(result.returncode == 0, "candidate contains dirty or untracked submodule content")
    fd, name = tempfile.mkstemp(prefix="pulmu-candidate-index.", dir=store.root.parent)
    os.close(fd)
    Path(name).unlink()
    environment = os.environ.copy()
    environment["GIT_INDEX_FILE"] = name
    try:
        subprocess.run(["git", "read-tree", "HEAD"], check=True, env=environment, capture_output=True)
        subprocess.run(["git", "add", "-A", "--", ":/"], check=True, env=environment, capture_output=True)
        return subprocess.run(["git", "write-tree"], check=True, env=environment, capture_output=True, text=True).stdout.strip()
    finally:
        Path(name).unlink(missing_ok=True)


def metadata_value(metadata: Path, name: str) -> str:
    path = metadata / name
    expect(path.is_file(), f"Pulmu metadata is missing {name}")
    return path.read_text(encoding="utf-8").rstrip("\n")


def current_candidate_fingerprint(store: Store, state: dict[str, Any]) -> str:
    metadata = store.root.parent / "pulmu-metadata"
    expect(metadata_value(metadata, "run_id") == state["runId"], "metadata runId conflicts with Run Context")
    branch = subprocess.run(["git", "branch", "--show-current"], check=True, capture_output=True, text=True).stdout.strip()
    head = subprocess.run(["git", "rev-parse", "HEAD"], check=True, capture_output=True, text=True).stdout.strip()
    base = state["git"]["baseBranch"]
    expect(isinstance(base, str) and bool(base), "Run Context base branch is missing")
    base_head = subprocess.run(["git", "rev-parse", base], check=True, capture_output=True, text=True).stdout.strip()
    tree = git_candidate_tree(store)
    expect(branch == state["git"]["branch"], "Git branch conflicts with Run Context")
    payload = (
        f"run={state['runId']}\nbranch={branch}\nbase={base}\n"
        f"base_head={base_head}\nhead={head}\ntree={tree}\n"
    )
    return subprocess.run(["git", "hash-object", "--stdin"], input=payload, check=True,
                          capture_output=True, text=True).stdout.strip()


def require_final_metadata(store: Store, state: dict[str, Any]) -> Path:
    metadata = store.root.parent / "pulmu-metadata"
    expect(metadata_value(metadata, "status") == "final", "stage requires finalized Shape metadata")
    expected = {
        "run_id": state["runId"], "task_type": state["task"]["type"],
        "forge": state["forge"], "risk": state["risk"],
        "areas": ",".join(state["areas"]), "pattern": str(state["pattern"]).lower(),
        "base_branch": state["git"]["baseBranch"], "branch": state["git"]["branch"],
    }
    for name, value in expected.items():
        expect(value is not None and metadata_value(metadata, name) == value,
               f"finalized metadata conflicts with Run Context: {name}")
    return metadata


def require_exact_evidence(store: Store, state: dict[str, Any], *names: str) -> str:
    metadata = require_final_metadata(store, state)
    fingerprint = current_candidate_fingerprint(store, state)
    for name in names:
        expect(metadata_value(metadata, name) == fingerprint, f"{name} does not match the current candidate")
    return fingerprint


def stored_candidate_fingerprint(metadata: Path, state: dict[str, Any]) -> str:
    payload = (
        f"run={state['runId']}\nbranch={metadata_value(metadata, 'candidate_branch')}\n"
        f"base={metadata_value(metadata, 'candidate_base')}\n"
        f"base_head={metadata_value(metadata, 'candidate_base_head')}\n"
        f"head={metadata_value(metadata, 'candidate_head')}\n"
        f"tree={metadata_value(metadata, 'candidate_tree')}\n"
    )
    return subprocess.run(["git", "hash-object", "--stdin"], input=payload, check=True,
                          capture_output=True, text=True).stdout.strip()


def require_ship_commit(store: Store, state: dict[str, Any], commit: str) -> Path:
    metadata = require_final_metadata(store, state)
    fingerprint = stored_candidate_fingerprint(metadata, state)
    for name in ("quench_fingerprint", "hone_fingerprint", "delivery_fingerprint"):
        expect(metadata_value(metadata, name) == fingerprint, f"{name} does not identify the reviewed candidate")
    branch = subprocess.run(["git", "branch", "--show-current"], check=True, capture_output=True, text=True).stdout.strip()
    head = subprocess.run(["git", "rev-parse", "HEAD"], check=True, capture_output=True, text=True).stdout.strip()
    tree = subprocess.run(["git", "rev-parse", f"{commit}^{{tree}}"], check=True, capture_output=True, text=True).stdout.strip()
    parent = subprocess.run(["git", "rev-parse", f"{commit}^"], check=True, capture_output=True, text=True).stdout.strip()
    status = subprocess.run(["git", "status", "--porcelain"], check=True, capture_output=True, text=True).stdout
    expect(branch == state["git"]["branch"] and head == commit and not status,
           "Ship result requires the exact clean commit on the recorded branch")
    expect(metadata_value(metadata, "candidate_branch") == branch
           and metadata_value(metadata, "candidate_base") == state["git"]["baseBranch"],
           "Ship commit provenance conflicts with the reviewed candidate")
    expect(tree == metadata_value(metadata, "candidate_tree")
           and parent == metadata_value(metadata, "candidate_head"),
           "Ship commit does not contain the reviewed candidate")
    return metadata


def required_reviewers(state: dict[str, Any], metadata: Path) -> list[str]:
    roles = ["pulmu_reviewer"]
    if state["forge"] in {"standard", "full"}:
        roles.append("pulmu_test_reviewer")
    if state["forge"] == "full" and metadata_value(metadata, "security_review") == "true":
        roles.append("pulmu_security_reviewer")
    if state["forge"] == "full" and metadata_value(metadata, "compatibility_review") == "true":
        roles.append("pulmu_compat_reviewer")
    if state["pattern"]:
        roles.append("pulmu_design_reviewer")
    return roles


STAGE_ICONS = {
    "ignite": "🔥 Ignite", "inspect": "🔎 Inspect", "shape": "📐 Shape", "hammer": "🔨 Hammer",
    "quench": "🌊 Quench", "hone": "🪨 Hone", "ship": "📦 Ship",
}


def command_detect(store: Store, _args: argparse.Namespace) -> int:
    try:
        with store.lock(exclusive=False):
            state = store.read()
    except ContextError as exc:
        print(f"PULMU_RUN_DETECTED=malformed\nPULMU_RUN_ERROR={concise(str(exc), 500)}")
        return 2
    if state is None:
        print("PULMU_RUN_DETECTED=false")
        return 1
    print("PULMU_RUN_DETECTED=true")
    print(f"PULMU_RUN_ID={state['runId']}")
    print(f"PULMU_RUN_STATUS={state['status']}")
    print(f"PULMU_RUN_STAGE={state['stage']['current']}")
    print(f"PULMU_RUN_BRANCH={state['git']['branch'] or ''}")
    return 0


def command_init(store: Store, args: argparse.Namespace) -> int:
    with store.lock():
        previous: dict[str, Any] | None
        try:
            previous = store.read()
        except ContextError as exc:
            quarantined = store.quarantine()
            print(f"⚠ Malformed Pulmu run quarantined: {quarantined.name} ({concise(str(exc), 160)})", file=sys.stderr)
            previous = None
        if previous is not None:
            if previous["status"] == "running":
                raise ContextError(
                    f"Pulmu run {previous['runId']} is still running at {previous['stage']['current']}; "
                    "finish or explicitly interrupt it before starting another run"
                )
            try:
                store.snapshot(previous)
            except (ContextError, OSError) as exc:
                print(f"⚠ Run Context history snapshot failed: {concise(str(exc), 160)}", file=sys.stderr)
        now = utc_now()
        state: dict[str, Any] = {
            "schemaVersion": SCHEMA_VERSION,
            "workflow": WORKFLOW,
            "pulmuVersion": concise(args.pulmu_version, 32),
            "runId": new_run_id(),
            "status": "running",
            "task": {"prompt": concise(args.task, 2000), "type": args.task_type},
            "forge": None,
            "risk": None,
            "areas": [],
            "pattern": False,
            "stage": {"current": "ignite", "status": "in_progress"},
            "git": {"baseBranch": concise(args.base, 512), "branch": concise(args.branch, 512), "commit": None},
            "agents": {"active": []},
            "retries": {"quench": 0, "hone": 0},
            "startedAt": now,
            "updatedAt": now,
            "completedAt": None,
            "interruptedAt": None,
            "pr": None,
            "error": None,
        }
        store.write(state)
    print(f"PULMU_RUN_ID={state['runId']}")
    print(f"PULMU_RUN_FILE={store.path}")
    return 0


def mutate(store: Store, expected_run_id: str | None, callback: Any) -> dict[str, Any]:
    with store.lock():
        state = read_required(store)
        require_running(state, expected_run_id)
        callback(state)
        touch(state)
        store.write(state)
        return state


def command_set_stage(store: Store, args: argparse.Namespace) -> int:
    with store.lock():
        state = read_required(store)
        if state["status"] == "completed" and args.stage == "ship" and state["stage"] == {"current": "ship", "status": "completed"}:
            if args.expect_run_id is not None:
                expect(state["runId"] == args.expect_run_id, "Run Context runId changed; refusing stale update")
        else:
            require_running(state, args.expect_run_id)
            current = state["stage"]["current"]
            expect(args.stage == current or STAGE_ORDER.index(args.stage) == STAGE_ORDER.index(current) + 1,
                   f"invalid Pulmu stage transition: {current} -> {args.stage}")
            if args.stage in {"hammer", "quench", "hone", "ship"}:
                metadata = require_final_metadata(store, state)
            if args.stage == "hammer":
                expect((metadata / "verification-plan").is_file(), "Hammer requires the Shape verification plan")
            if args.stage == "hone":
                require_exact_evidence(store, state, "quench_fingerprint")
            if args.stage == "ship":
                require_exact_evidence(store, state, "quench_fingerprint", "hone_fingerprint", "delivery_fingerprint")
            state["stage"].update(current=args.stage, status="in_progress")
            touch(state)
            store.write(state)
    print(f"PULMU_RUN_ID={state['runId']}\nPULMU_RUN_STAGE={args.stage}")
    return 0


def command_set_agents(store: Store, args: argparse.Namespace) -> int:
    unique = list(dict.fromkeys(args.agents))
    for agent in unique:
        expect(AGENT_RE.fullmatch(agent) is not None, f"invalid Pulmu agent name: {agent}")
    expect(len(unique) <= 16, "too many active agents")
    state = mutate(store, args.expect_run_id, lambda item: item["agents"].update(active=unique))
    print(f"PULMU_RUN_ID={state['runId']}\nPULMU_RUN_AGENTS={','.join(unique)}")
    return 0


def command_sync_metadata(store: Store, args: argparse.Namespace) -> int:
    areas = [area.strip() for area in args.areas.split(",") if area.strip()]
    expect(0 < len(areas) <= 3 and len(set(areas)) == len(areas), "metadata requires one to three unique areas")
    expect(all(AREA_RE.fullmatch(area) for area in areas), "invalid metadata area")
    pattern = args.pattern == "true"

    def update(state: dict[str, Any]) -> None:
        expect(state["stage"]["current"] == "shape", "task metadata can be finalized only during Shape")
        expect(state["task"]["type"] == args.task_type, "Run Context task type conflicts with finalized metadata")
        expect(state["git"]["baseBranch"] == args.base, "Run Context base branch conflicts with finalized metadata")
        expect(state["git"]["branch"] == args.branch, "Run Context branch conflicts with finalized metadata")
        state.update(forge=args.forge, risk=args.risk, areas=areas, pattern=pattern)

    state = mutate(store, args.expect_run_id, update)
    print(f"PULMU_RUN_ID={state['runId']}\nPULMU_RUN_METADATA=synchronized")
    return 0


def command_increment_retry(store: Store, args: argparse.Namespace) -> int:
    with store.lock():
        state = read_required(store)
        require_running(state, args.expect_run_id)
        expect(state["stage"]["current"] == args.stage, f"{args.stage} retry must be recorded from {args.stage}")
        state["retries"][args.stage] += 1
        limit = RETRY_LIMITS[args.stage]
        expect(state["retries"][args.stage] <= limit, f"{args.stage} retry limit ({limit}) exhausted")
        state["stage"] = {"current": "hammer", "status": "in_progress"}
        metadata = store.root.parent / "pulmu-metadata"
        for name in (
            "quench_fingerprint", "hone_fingerprint", "delivery_fingerprint", "quench_attempt",
            "candidate_tree", "candidate_head", "candidate_branch", "candidate_base", "candidate_base_head",
        ):
            (metadata / name).unlink(missing_ok=True)
        (store.root.parent / "pulmu-quench.log").unlink(missing_ok=True)
        reviews = store.root.parent / "pulmu-reviews"
        if reviews.is_dir():
            for result in reviews.iterdir():
                if result.is_file() and not result.is_symlink():
                    result.unlink()
        touch(state)
        store.write(state)
    print(f"PULMU_RUN_ID={state['runId']}\nPULMU_RUN_RETRY_{args.stage.upper()}={state['retries'][args.stage]}")
    return 0


def command_recover_ship(store: Store, args: argparse.Namespace) -> int:
    with store.lock():
        state = read_required(store)
        expect(state["runId"] == args.expect_run_id, "Run Context runId changed; refusing stale recovery")
        expect(state["status"] in {"failed", "interrupted"}, "Ship recovery requires a failed or interrupted run")
        expect(state["stage"]["current"] == "ship", "only a terminal Ship stage can be recovered")
        expect(re.fullmatch(r"[0-9a-fA-F]{40,64}", args.commit or "") is not None, "Ship recovery requires a full commit SHA")
        require_ship_commit(store, state, args.commit.lower())
        # Preserve the original terminal outcome before reopening this exact Ship.
        store.snapshot(state)
        state["status"] = "running"
        state["stage"] = {"current": "ship", "status": "in_progress"}
        state["agents"]["active"] = []
        state["git"]["commit"] = args.commit.lower()
        state["completedAt"] = None
        state["interruptedAt"] = None
        state["error"] = None
        touch(state)
        store.write(state)
        atomic_text(store.root / "ship-recovery", f"{state['runId']}\n{args.commit.lower()}\n")
    print(f"PULMU_RUN_ID={state['runId']}\nPULMU_RUN_STATUS=running\nPULMU_RUN_STAGE=ship")
    return 0


def command_validate_ship(store: Store, args: argparse.Namespace) -> int:
    with store.lock(exclusive=False):
        state = read_required(store)
        expect(state["runId"] == args.expect_run_id, "Run Context runId changed; refusing stale Ship validation")
        expect(state["status"] in {"running", "completed"},
               f"Ship validation cannot continue from {state['status']}")
        expect(state["stage"]["current"] == "ship", "a resumed commit requires the Ship stage")
        expect(re.fullmatch(r"[0-9a-fA-F]{40,64}", args.commit or "") is not None,
               "Ship validation requires a full commit SHA")
        require_ship_commit(store, state, args.commit.lower())
    print(f"PULMU_RUN_ID={state['runId']}\nPULMU_SHIP_COMMIT=validated")
    return 0


def command_quench_evidence(store: Store, args: argparse.Namespace) -> int:
    metadata = store.root.parent / "pulmu-metadata"
    log = store.root.parent / "pulmu-quench.log"
    with store.lock():
        state = read_required(store)
        require_running(state, args.expect_run_id)
        expect(state["stage"]["current"] == "quench", "Quench evidence requires the Quench stage")
        expect(metadata.is_dir(), "Pulmu metadata directory does not exist")
        run_file = metadata / "run_id"
        expect(run_file.is_file() and run_file.read_text(encoding="utf-8").strip() == args.expect_run_id,
               "metadata runId changed; refusing stale Quench operation")
        evidence = (
            "quench_fingerprint", "hone_fingerprint", "delivery_fingerprint",
            "candidate_tree", "candidate_head", "candidate_branch", "candidate_base", "candidate_base_head",
        )
        if args.action == "begin":
            expect(isinstance(args.attempt, str) and re.fullmatch(r"[A-Za-z0-9._-]{8,128}", args.attempt) is not None,
                   "invalid Quench attempt token")
            for name in evidence:
                (metadata / name).unlink(missing_ok=True)
            log.unlink(missing_ok=True)
            reviews = store.root.parent / "pulmu-reviews"
            if reviews.is_dir():
                for result in reviews.iterdir():
                    if result.is_file() and not result.is_symlink():
                        result.unlink()
            atomic_text(metadata / "quench_attempt", args.attempt + "\n")
        else:
            attempt_file = metadata / "quench_attempt"
            expect(attempt_file.is_file() and attempt_file.read_text(encoding="utf-8").strip() == args.attempt,
                   "a newer Quench attempt superseded this result")
            expect(args.branch == state["git"]["branch"], "Quench branch conflicts with Run Context")
            expect(args.base == state["git"]["baseBranch"], "Quench base conflicts with Run Context")
            expect(re.fullmatch(r"[0-9a-f]{40,64}", args.base_head or "") is not None, "invalid Quench base commit")
            expect(re.fullmatch(r"[0-9a-f]{40,64}", args.head or "") is not None, "invalid Quench HEAD")
            expect(re.fullmatch(r"[0-9a-f]{40,64}", args.tree or "") is not None, "invalid Quench candidate tree")
            expect(re.fullmatch(r"[0-9a-f]{40,64}", args.fingerprint or "") is not None, "invalid Quench fingerprint")
            expect(isinstance(args.log, str) and bool(args.log), "Quench log is missing")
            source = Path(args.log)
            expect(source.is_file(), "Quench log is missing")
            current_branch = subprocess.run(["git", "branch", "--show-current"], check=True, capture_output=True, text=True).stdout.strip()
            current_head = subprocess.run(["git", "rev-parse", "HEAD"], check=True, capture_output=True, text=True).stdout.strip()
            current_base = subprocess.run(["git", "rev-parse", args.base], check=True, capture_output=True, text=True).stdout.strip()
            expect(current_branch == args.branch and current_head == args.head and current_base == args.base_head,
                   "Git identity changed before Quench evidence publication")
            expect(git_candidate_tree(store) == args.tree, "candidate changed before Quench evidence publication")
            values = {
                "candidate_tree": args.tree,
                "candidate_head": args.head,
                "candidate_branch": args.branch,
                "candidate_base": args.base,
                "candidate_base_head": args.base_head,
            }
            for name, value in values.items():
                atomic_text(metadata / name, value + "\n")
            for name in ("hone_fingerprint", "delivery_fingerprint"):
                (metadata / name).unlink(missing_ok=True)
            atomic_copy(source, log)
            atomic_text(metadata / "quench_fingerprint", args.fingerprint + "\n")
            attempt_file.unlink(missing_ok=True)
    print(f"PULMU_RUN_ID={state['runId']}\nPULMU_QUENCH_EVIDENCE={args.action}")
    return 0


def command_verification_plan(store: Store, args: argparse.Namespace) -> int:
    metadata = store.root.parent / "pulmu-metadata"
    source = Path(args.plan)
    with store.lock():
        state = read_required(store)
        require_running(state, args.expect_run_id)
        expect(state["stage"]["current"] == "shape", "verification plan can be changed only during Shape")
        run_file = metadata / "run_id"
        expect(run_file.is_file() and run_file.read_text(encoding="utf-8").strip() == args.expect_run_id,
               "metadata runId changed; refusing stale verification plan")
        expect(source.is_file() and source.stat().st_size > 0, "verification plan is empty")
        atomic_copy(source, metadata / "verification-plan")
        for name in ("quench_fingerprint", "hone_fingerprint", "delivery_fingerprint"):
            (metadata / name).unlink(missing_ok=True)
        (metadata / "quench_attempt").unlink(missing_ok=True)
    print(f"PULMU_RUN_ID={state['runId']}\nPULMU_VERIFICATION_PLAN=ready")
    return 0


def command_review_attempt(store: Store, args: argparse.Namespace) -> int:
    expect(args.role in REVIEW_ROLES, "invalid Pulmu reviewer role")
    with store.lock():
        state = read_required(store)
        require_running(state, args.expect_run_id)
        expect(state["stage"]["current"] == "hone", "review attempts can be opened only during Hone")
        metadata = require_final_metadata(store, state)
        candidate = require_exact_evidence(store, state, "quench_fingerprint")
        expect(args.candidate == candidate, "review attempt candidate does not match Quench evidence")
        expect(args.role in required_reviewers(state, metadata), f"{args.role} is not required for this run")
        reviews = store.root.parent / "pulmu-reviews"
        reviews.mkdir(mode=0o700, exist_ok=True)
        path = reviews / f"{args.role}.json"
        submissions = 1
        if path.is_file():
            try:
                prior = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, UnicodeError, json.JSONDecodeError) as exc:
                raise ContextError(f"malformed stored result from {args.role}: {exc}") from exc
            if prior.get("candidate") == candidate:
                expect(prior.get("completion") == "incomplete", f"{args.role} already submitted a completed result")
                submissions = prior.get("submissions", 0) + 1
        expect(isinstance(submissions, int) and not isinstance(submissions, bool) and submissions <= 2,
               f"{args.role} result repair limit exhausted")
        receipt = {
            "role": args.role, "runId": state["runId"], "candidate": candidate,
            "completion": "incomplete", "severity": "high",
            "findings": "Reviewer result was not received.", "evidence": "not received", "limitations": "pending",
            "submissions": submissions, "received": False,
        }
        atomic_text(path, json.dumps(receipt, ensure_ascii=False, indent=2) + "\n")
    print(f"PULMU_RUN_ID={state['runId']}\nPULMU_REVIEW_ATTEMPT={args.role}\nPULMU_REVIEW_ATTEMPT_NUMBER={submissions}")
    return 0


def command_review_result(store: Store, args: argparse.Namespace) -> int:
    expect(args.role in REVIEW_ROLES, "invalid Pulmu reviewer role")
    expect(args.completion in {"complete", "incomplete"}, "invalid review completion")
    expect(args.severity in {"none", "low", "medium", "high"}, "invalid review severity")
    expect(not (args.completion == "incomplete" and args.severity == "none"), "incomplete review must explain a severity")
    findings = concise(args.findings, 2000)
    evidence = concise(args.evidence, 2000)
    limitations = concise(args.limitations, 1000)
    expect(bool(findings), "review findings summary is required")
    expect(bool(evidence), "review evidence summary is required")
    with store.lock():
        state = read_required(store)
        require_running(state, args.expect_run_id)
        expect(state["stage"]["current"] == "hone", "review results can be recorded only during Hone")
        metadata = require_final_metadata(store, state)
        candidate = require_exact_evidence(store, state, "quench_fingerprint")
        expect(args.candidate == candidate, "review result candidate does not match Quench evidence")
        expect(args.role in required_reviewers(state, metadata), f"{args.role} is not required for this run")
        reviews = store.root.parent / "pulmu-reviews"
        path = reviews / f"{args.role}.json"
        expect(path.is_file(), f"open a review attempt for {args.role} before recording its result")
        try:
            prior = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as exc:
            raise ContextError(f"malformed stored result from {args.role}: {exc}") from exc
        expect(prior.get("role") == args.role and prior.get("runId") == state["runId"]
               and prior.get("candidate") == candidate and prior.get("received") is False,
               f"no matching open review attempt for {args.role}")
        submissions = prior.get("submissions")
        expect(isinstance(submissions, int) and not isinstance(submissions, bool) and 1 <= submissions <= 2,
               f"invalid review attempt for {args.role}")
        receipt = {
            "role": args.role, "runId": state["runId"], "candidate": candidate,
            "completion": args.completion, "severity": args.severity,
            "findings": findings, "evidence": evidence, "limitations": limitations,
            "submissions": submissions, "received": True,
        }
        atomic_text(path, json.dumps(receipt, ensure_ascii=False, indent=2) + "\n")
    print(f"PULMU_RUN_ID={state['runId']}\nPULMU_REVIEW_RESULT={args.role}")
    return 0


def command_review_check(store: Store, args: argparse.Namespace) -> int:
    with store.lock():
        state = read_required(store)
        require_running(state, args.expect_run_id)
        expect(state["stage"]["current"] == "hone", "Hone PASS can be recorded only during Hone")
        metadata = require_final_metadata(store, state)
        candidate = require_exact_evidence(store, state, "quench_fingerprint")
        reviews = store.root.parent / "pulmu-reviews"
        for role in required_reviewers(state, metadata):
            path = reviews / f"{role}.json"
            expect(path.is_file(), f"Hone requires a result from {role}")
            try:
                receipt = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, UnicodeError, json.JSONDecodeError) as exc:
                raise ContextError(f"malformed result from {role}: {exc}") from exc
            expected_fields = {"role", "runId", "candidate", "completion", "severity", "findings", "evidence", "limitations", "submissions", "received"}
            expect(isinstance(receipt, dict) and set(receipt) == expected_fields, f"malformed result from {role}")
            expect(receipt["role"] == role and receipt["runId"] == state["runId"]
                   and receipt["candidate"] == candidate, f"stale or mismatched result from {role}")
            expect(receipt["completion"] == "complete", f"incomplete result from {role}")
            expect(receipt["received"] is True, f"missing result from {role}")
            expect(receipt["severity"] in {"none", "low"}, f"blocking {receipt['severity']} finding from {role}")
            expect(isinstance(receipt["findings"], str) and bool(receipt["findings"]), f"empty result from {role}")
            expect(isinstance(receipt["evidence"], str) and bool(receipt["evidence"]), f"empty evidence from {role}")
            expect(isinstance(receipt["limitations"], str), f"malformed limitations from {role}")
            expect(isinstance(receipt["submissions"], int) and not isinstance(receipt["submissions"], bool)
                   and 1 <= receipt["submissions"] <= 2, f"invalid submission count from {role}")
        atomic_text(metadata / "hone_fingerprint", candidate + "\n")
    print(f"PULMU_RUN_ID={state['runId']}\nPULMU_REVIEW_GATE=pass")
    return 0


def command_complete(store: Store, args: argparse.Namespace) -> int:
    with store.lock():
        state = read_required(store)
        expect(args.commit and re.fullmatch(r"[0-9a-fA-F]{7,64}", args.commit), "completion requires a valid commit SHA")
        if state["status"] == "completed":
            if args.expect_run_id is not None:
                expect(state["runId"] == args.expect_run_id, "Run Context runId changed; refusing stale update")
            expected_pr = None if args.delivery == "local" else {"number": args.pr_number, "url": args.pr_url}
            expect(state["git"]["commit"] == args.commit.lower() and state["pr"] == expected_pr, "completed Run Context conflicts with Ship result")
            print(f"PULMU_RUN_ID={state['runId']}\nPULMU_RUN_STATUS=completed")
            return 0
        require_running(state, args.expect_run_id)
        expect(state["stage"]["current"] == "ship", "Run Context can complete only from Ship")
        expect(len(args.commit) >= 40, "completion requires a full commit SHA")
        metadata = require_ship_commit(store, state, args.commit.lower())
        if args.delivery == "github":
            expect(args.pr_url is not None and args.pr_number is not None, "GitHub completion requires PR number and URL")
            match = PR_URL_RE.fullmatch(args.pr_url)
            expect(match is not None and int(match.group(1)) == args.pr_number, "invalid or mismatched GitHub PR URL/number")
            expected_url = f"https://{metadata_value(metadata, 'github_repo')}/pull/{args.pr_number}"
            expect(args.pr_url.casefold() == expected_url.casefold(),
                   "GitHub PR URL does not match the recorded origin repository")
            state["pr"] = {"number": args.pr_number, "url": args.pr_url}
        else:
            expect(args.pr_url is None and args.pr_number is None, "local completion must not include a PR")
            state["pr"] = None
        now = next_timestamp(state)
        state["status"] = "completed"
        state["stage"] = {"current": "ship", "status": "completed"}
        state["agents"]["active"] = []
        state["git"]["commit"] = args.commit.lower()
        state["completedAt"] = now
        state["interruptedAt"] = None
        state["updatedAt"] = now
        state["error"] = None
        store.write(state)
        recovery = store.root / "ship-recovery"
        recovered = False
        if recovery.is_file() and not recovery.is_symlink():
            recovery_lines = recovery.read_text(encoding="utf-8").splitlines()
            recovered = recovery_lines == [state["runId"], args.commit.lower()]
        try:
            store.snapshot(state, suffix="recovered" if recovered else None)
        except (ContextError, OSError) as exc:
            print(f"⚠ Run Context history snapshot failed: {concise(str(exc), 160)}", file=sys.stderr)
        if recovered:
            recovery.unlink(missing_ok=True)
    print(f"PULMU_RUN_ID={state['runId']}\nPULMU_RUN_STATUS=completed")
    return 0


def command_fail(store: Store, args: argparse.Namespace) -> int:
    expect(ERROR_CODE_RE.fullmatch(args.code) is not None, "failure code must be uppercase snake case")

    def update(state: dict[str, Any]) -> None:
        now = next_timestamp(state)
        state["status"] = "failed"
        state["stage"]["status"] = "failed"
        state["agents"]["active"] = []
        state["error"] = {"code": args.code, "message": concise(args.message, 500)}
        state["updatedAt"] = now

    with store.lock():
        state = read_required(store)
        require_running(state, args.expect_run_id)
        update(state)
        store.write(state)
        try:
            store.snapshot(state)
        except (ContextError, OSError) as exc:
            print(f"⚠ Run Context history snapshot failed: {concise(str(exc), 160)}", file=sys.stderr)
    print(f"PULMU_RUN_ID={state['runId']}\nPULMU_RUN_STATUS=failed")
    return 0


def command_interrupt(store: Store, args: argparse.Namespace) -> int:
    def update(state: dict[str, Any]) -> None:
        now = next_timestamp(state)
        state["status"] = "interrupted"
        state["stage"]["status"] = "interrupted"
        state["agents"]["active"] = []
        state["interruptedAt"] = now
        state["updatedAt"] = now
        if args.message:
            state["error"] = {"code": "INTERRUPTED", "message": concise(args.message, 500)}

    with store.lock():
        state = read_required(store)
        require_running(state, args.expect_run_id)
        update(state)
        store.write(state)
        try:
            store.snapshot(state)
        except (ContextError, OSError) as exc:
            print(f"⚠ Run Context history snapshot failed: {concise(str(exc), 160)}", file=sys.stderr)
    print(f"PULMU_RUN_ID={state['runId']}\nPULMU_RUN_STATUS=interrupted")
    return 0


def command_show(store: Store, args: argparse.Namespace) -> int:
    with store.lock(exclusive=False):
        state = read_required(store)
    if args.format == "json":
        json.dump(state, sys.stdout, ensure_ascii=False, indent=2)
        print()
        return 0
    agents = ", ".join(state["agents"]["active"]) or "none"
    retries = f"Quench {state['retries']['quench']} · Hone {state['retries']['hone']}"
    pr = state["pr"]["url"] if state["pr"] else "pending" if state["status"] == "running" else "not created"
    print("Pulmu Run\n")
    print(f"Status   {state['status']}")
    print(f"Run      {state['runId']}")
    print(f"Forge    {state['forge'].title() if state['forge'] else 'Pending'}")
    print(f"Stage    {STAGE_ICONS[state['stage']['current']]}")
    print(f"Task     {state['task']['prompt']}")
    print(f"Branch   {state['git']['branch']}")
    print(f"Agents   {agents}")
    print(f"Retries  {retries}")
    print(f"PR       {pr}")
    return 0


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description="Manage Pulmu machine-readable Run Context")
    sub = result.add_subparsers(dest="command", required=True)
    sub.add_parser("detect")
    init = sub.add_parser("init")
    init.add_argument("--task-type", choices=sorted(TASK_TYPES), required=True)
    init.add_argument("--task", required=True)
    init.add_argument("--base", required=True)
    init.add_argument("--branch", required=True)
    init.add_argument("--pulmu-version", default=DEFAULT_PULMU_VERSION)
    stage = sub.add_parser("set-stage")
    stage.add_argument("stage", choices=sorted(STAGES))
    agents = sub.add_parser("set-agents")
    agents.add_argument("agents", nargs="*")
    metadata = sub.add_parser("sync-metadata")
    metadata.add_argument("--type", dest="task_type", choices=sorted(TASK_TYPES), required=True)
    metadata.add_argument("--forge", choices=sorted(FORGES), required=True)
    metadata.add_argument("--risk", choices=sorted(RISKS), required=True)
    metadata.add_argument("--areas", required=True)
    metadata.add_argument("--pattern", choices=("true", "false"), required=True)
    metadata.add_argument("--base", required=True)
    metadata.add_argument("--branch", required=True)
    retry = sub.add_parser("increment-retry")
    retry.add_argument("stage", choices=("quench", "hone"))
    quench = sub.add_parser("quench-evidence")
    quench.add_argument("action", choices=("begin", "pass"))
    quench.add_argument("--branch")
    quench.add_argument("--base")
    quench.add_argument("--base-head")
    quench.add_argument("--head")
    quench.add_argument("--tree")
    quench.add_argument("--fingerprint")
    quench.add_argument("--log")
    quench.add_argument("--attempt", required=True)
    verification = sub.add_parser("verification-plan")
    verification.add_argument("--plan", required=True)
    review_attempt = sub.add_parser("review-attempt")
    review_attempt.add_argument("--role", required=True)
    review_attempt.add_argument("--candidate", required=True)
    review = sub.add_parser("review-result")
    review.add_argument("--role", required=True)
    review.add_argument("--candidate", required=True)
    review.add_argument("--completion", required=True)
    review.add_argument("--severity", required=True)
    review.add_argument("--findings", required=True)
    review.add_argument("--evidence", required=True)
    review.add_argument("--limitations", default="none")
    review_check = sub.add_parser("review-check")
    complete = sub.add_parser("complete")
    complete.add_argument("--delivery", choices=("local", "github"), required=True)
    complete.add_argument("--commit", required=True)
    complete.add_argument("--pr-number", type=int)
    complete.add_argument("--pr-url")
    recover = sub.add_parser("recover-ship")
    recover.add_argument("--commit", required=True)
    validate_ship = sub.add_parser("validate-ship")
    validate_ship.add_argument("--commit", required=True)
    fail = sub.add_parser("fail")
    fail.add_argument("--code", required=True)
    fail.add_argument("--message", required=True)
    interrupt = sub.add_parser("interrupt")
    interrupt.add_argument("--message")
    show = sub.add_parser("show")
    show.add_argument("--format", choices=("json", "text"), default="json")
    for command in (stage, agents, metadata, retry, quench, verification, review_attempt, review, review_check,
                    complete, recover, validate_ship, fail, interrupt):
        command.add_argument("--expect-run-id", required=True)
    return result


def main() -> int:
    args = parser().parse_args()
    store = Store()
    commands = {
        "detect": command_detect,
        "init": command_init,
        "set-stage": command_set_stage,
        "set-agents": command_set_agents,
        "sync-metadata": command_sync_metadata,
        "increment-retry": command_increment_retry,
        "quench-evidence": command_quench_evidence,
        "verification-plan": command_verification_plan,
        "review-attempt": command_review_attempt,
        "review-result": command_review_result,
        "review-check": command_review_check,
        "complete": command_complete,
        "recover-ship": command_recover_ship,
        "validate-ship": command_validate_ship,
        "fail": command_fail,
        "interrupt": command_interrupt,
        "show": command_show,
    }
    try:
        return commands[args.command](store, args)
    except ContextError as exc:
        die(str(exc))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
