"""Run-local intent and evidence. Integrity checks do not authenticate tool execution."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import tempfile


class EvidenceError(RuntimeError):
    pass


def check(condition, message):
    if not condition:
        raise EvidenceError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode()


def read_bytes(path, limit=25 * 1024 * 1024):
    path = Path(path)
    check(path.is_file() and not path.is_symlink(), f"evidence file missing or symlinked: {path}")
    check(path.stat().st_size <= limit, f"evidence file too large: {path}")
    return path.read_bytes()


def read_json(path):
    try:
        return json.loads(read_bytes(path, 1024 * 1024))
    except (ValueError, UnicodeError) as exc:
        raise EvidenceError(f"invalid evidence JSON: {path}") from exc


def text(value, name):
    check(isinstance(value, str) and bool(value.strip()) and len(value) <= 16000,
          f"{name} must be nonempty text (at most 16000 characters)")


def texts(value, name, required=False):
    check(isinstance(value, list) and len(value) <= 100 and (bool(value) or not required), f"invalid {name}")
    for item in value:
        text(item, name)


def private_directory(path):
    check(not path.is_symlink(), f"evidence directory is symlinked: {path}")
    path.mkdir(mode=0o700, exist_ok=True)
    check(path.is_dir(), f"invalid evidence directory: {path}")
    os.chmod(path, 0o700)


def atomic(path, data):
    check(not path.is_symlink(), f"evidence destination is symlinked: {path}")
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=".evidence-")
    try:
        with os.fdopen(fd, "wb") as output:
            output.write(data)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


class Evidence:
    def __init__(self, store, state):
        self.state = state
        self.metadata = store.root.parent / "pulmu-metadata"
        version = self.metadata / "version"
        # Old Ignite/bootstrap paths also wrote version 1 explicitly. Missing
        # provenance is corruption, not permission to weaken a new run's gates.
        self.version = read_bytes(version).decode().strip()
        check(self.version in {"1", "2", "3"}, "unsupported Pulmu metadata version")
        self.root = store.root / "evidence" / state["runId"]
        # Check even on read: never traverse a redirected evidence directory.
        for path in (self.root.parent, self.root):
            check(not path.is_symlink(), f"evidence directory is symlinked: {path}")

    @property
    def required(self):
        return self.version in {"2", "3"}

    @property
    def models_required(self):
        return self.version == "3"

    def prepare(self):
        private_directory(self.root.parent)
        private_directory(self.root)

    def validate_shape(self, contract):
        fields = {"acceptance", "boundaries", "clarifications", "assumptions", "patternBrief", "ui"}
        check(isinstance(contract, dict) and set(contract) == fields, "invalid Shape contract fields")
        texts(contract["acceptance"], "acceptance", True)
        texts(contract["boundaries"], "boundaries", True)
        texts(contract["assumptions"], "assumptions")
        check(isinstance(contract["clarifications"], list) and len(contract["clarifications"]) <= 100,
              "invalid clarifications")
        for answer in contract["clarifications"]:
            check(isinstance(answer, dict) and set(answer) == {"answer", "source"}, "invalid clarification")
            text(answer["answer"], "clarification answer")
            text(answer["source"], "clarification source")
        check(isinstance(contract["patternBrief"], str), "invalid Pattern brief")
        if self.state["pattern"]:
            text(contract["patternBrief"], "Pattern brief")
        ui = contract["ui"]
        check(isinstance(ui, dict) and set(ui) == {"required", "reason", "scenarios"}, "invalid UI plan")
        check(type(ui["required"]) is bool, "UI required must be a boolean")
        text(ui["reason"], "UI scope reason")
        check(isinstance(ui["scenarios"], list) and len(ui["scenarios"]) <= 100, "invalid UI scenarios")
        check(bool(ui["scenarios"]) == ui["required"], "required UI needs scenarios; skipped UI cannot have scenarios")
        check(not self.state["pattern"] or ui["required"], "Pattern requires rendered UI verification")
        ids = set()
        for scenario in ui["scenarios"]:
            check(isinstance(scenario, dict) and set(scenario) == {"id", "surface", "steps", "expected", "viewport"},
                  "invalid UI scenario")
            check(isinstance(scenario["id"], str) and re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", scenario["id"])
                  and scenario["id"] not in ids, "invalid or duplicate UI scenario ID")
            ids.add(scenario["id"])
            check(scenario["surface"] in {"browser", "native"}, "invalid UI surface")
            texts(scenario["steps"], "UI steps", True)
            text(scenario["expected"], "expected UI result")
            text(scenario["viewport"], "UI viewport/device")
        return contract

    def record_shape(self, source):
        self.prepare()
        check(not (self.root / "seal.json").exists(), "Shape is sealed; replan before changing intent")
        contract = self.validate_shape(read_json(source))
        payload = {"schemaVersion": 1, "runId": self.state["runId"], "contract": contract}
        data = encoded(payload)
        private_directory(self.root / "contracts")
        atomic(self.root / "contracts" / (digest(data) + ".json"), data)
        atomic(self.root / "shape.json", data)

    def shape(self):
        payload = read_json(self.root / "shape.json")
        check(isinstance(payload, dict) and payload.get("schemaVersion") == 1
              and payload.get("runId") == self.state["runId"], "Shape run identity mismatch")
        return self.validate_shape(payload.get("contract"))

    def seal(self):
        if not self.required:
            return
        self.shape()
        seal = {"shape": digest(read_bytes(self.root / "shape.json")),
                "plan": digest(read_bytes(self.metadata / "verification-plan"))}
        path = self.root / "seal.json"
        if path.exists():
            check(read_json(path) == seal, "sealed Shape or verification plan changed; replan required")
        else:
            atomic(path, encoded(seal))

    def require(self):
        if not self.required:
            return None
        check((self.root / "seal.json").is_file(), "missing sealed Shape contract")
        self.seal()
        return self.shape()

    def invalidate(self, replan=False):
        if not self.required:
            return
        ui = self.root / "ui"
        check(not ui.is_symlink(), "UI evidence directory is symlinked")
        if ui.is_dir():
            for path in ui.glob("*.json"):
                path.unlink()
        if replan:
            for name in ("shape.json", "seal.json"):
                (self.root / name).unlink(missing_ok=True)

    def capture(self, source):
        return self.capture_bytes(read_bytes(source))

    def capture_bytes(self, data):
        check(bool(data), "empty evidence artifact")
        self.prepare()
        private_directory(self.root / "artifacts")
        sha = digest(data)
        atomic(self.root / "artifacts" / sha, data)
        return sha

    def artifact(self, sha):
        check(isinstance(sha, str) and re.fullmatch(r"[a-f0-9]{64}", sha), "invalid artifact digest")
        check(not (self.root / "artifacts").is_symlink(), "artifact directory is symlinked")
        data = read_bytes(self.root / "artifacts" / sha)
        check(digest(data) == sha, "recorded evidence artifact changed")
        return data

    def record_ui(self, source, candidate, tree):
        contract = self.require()
        check(contract is not None, "UI receipts require metadata version 2")
        receipt = read_json(source)
        fields = {"runId", "candidate", "scenario", "tool", "toolCall", "target", "buildTree",
                  "steps", "observed", "result", "limitations", "artifacts"}
        check(isinstance(receipt, dict) and set(receipt) == fields, "invalid UI receipt fields")
        check(receipt["runId"] == self.state["runId"] and receipt["candidate"] == candidate,
              "UI evidence run/candidate mismatch")
        check(receipt["buildTree"] == tree, "UI evidence must identify the tested candidate build tree")
        check(receipt["scenario"] in {s["id"] for s in contract["ui"]["scenarios"]}, "unknown UI scenario")
        for key in ("tool", "toolCall", "target", "observed", "limitations"):
            text(receipt[key], key)
        texts(receipt["steps"], "performed UI steps", True)
        check(receipt["result"] in {"pass", "fail", "blocked"}, "invalid UI result")
        texts(receipt["artifacts"], "UI artifacts", receipt["result"] == "pass")
        receipt["artifacts"] = [self.capture(path) for path in receipt["artifacts"]]
        receipt["shape"] = read_json(self.root / "seal.json")["shape"]
        receipt["source"] = self.capture_bytes(encoded(receipt))
        private_directory(self.root / "ui")
        atomic(self.root / "ui" / (receipt["scenario"] + ".json"), encoded(receipt))

    def require_ui(self, candidate):
        contract = self.require()
        if contract is None:
            return
        check(not (self.root / "ui").is_symlink(), "UI evidence directory is symlinked")
        for scenario in contract["ui"]["scenarios"]:
            receipt = read_json(self.root / "ui" / (scenario["id"] + ".json"))
            check(isinstance(receipt, dict), "invalid stored UI receipt")
            try:
                original = json.loads(self.artifact(receipt.get("source")))
            except (ValueError, UnicodeError) as exc:
                raise EvidenceError("invalid original UI observation") from exc
            check(original == {key: value for key, value in receipt.items() if key != "source"},
                  "recorded UI observation changed")
            check(isinstance(receipt, dict) and receipt.get("runId") == self.state["runId"] and receipt.get("candidate") == candidate
                  and receipt.get("scenario") == scenario["id"]
                  and receipt.get("shape") == read_json(self.root / "seal.json")["shape"], "stale UI evidence")
            check(receipt.get("result") == "pass", f"UI scenario {scenario['id']} has not passed")
            check(bool(receipt.get("artifacts")), "missing UI artifacts")
            for artifact in receipt["artifacts"]:
                self.artifact(artifact)

    def review_provenance(self, source, receipt):
        check(source, "review requires execution/source provenance JSON")
        data = read_json(source)
        fields = {"executionId", "contextMode", "input", "result"}
        check(isinstance(data, dict) and set(data) in (fields, fields | {"invocationId"}),
              "invalid review provenance")
        text(data["executionId"], "review execution ID")
        expected = "self" if receipt["role"] == "pulmu_self_review" else "fresh"
        check(data["contextMode"] == expected, "review context mode conflicts with review role")
        original = read_json(data["result"])
        check(isinstance(original, dict), "original review result must be an object")
        for key in ("role", "runId", "candidate", "completion", "severity", "findings", "evidence", "limitations"):
            check(original.get(key) == receipt[key], f"review source disagrees with recorded {key}")
        proof = {"executionId": data["executionId"], "contextMode": data["contextMode"],
                 "input": self.capture(data["input"]), "result": self.capture(data["result"]),
                 "shape": read_json(self.root / "seal.json")["shape"]}
        if "invocationId" in data:
            text(data["invocationId"], "invocation ID")
            proof["invocationId"] = data["invocationId"]
        from pulmu_agents import AgentRecords
        proof["modelExecution"] = AgentRecords(self).review_snapshot(proof, receipt)
        check("invocationId" not in proof or proof["modelExecution"] is not None, "missing named model invocation")
        return proof

    def require_review(self, receipt):
        if not self.required:
            return
        proof = receipt.get("provenance")
        check(isinstance(proof, dict), "missing review execution/source provenance")
        text(proof.get("executionId"), "review execution ID")
        check(proof.get("contextMode") == ("self" if receipt["role"] == "pulmu_self_review" else "fresh"),
              "review context provenance mismatch")
        check(proof.get("shape") == read_json(self.root / "seal.json")["shape"], "stale review intent")
        self.artifact(proof.get("input"))
        try:
            original = json.loads(self.artifact(proof.get("result")))
        except (ValueError, UnicodeError) as exc:
            raise EvidenceError("invalid original review result") from exc
        check(isinstance(original, dict), "original review result must be an object")
        for key in ("role", "runId", "candidate", "completion", "severity", "findings", "evidence", "limitations"):
            check(original.get(key) == receipt[key], f"review source disagrees with recorded {key}")
        from pulmu_agents import AgentRecords
        records = AgentRecords(self)
        snapshot = records.review_snapshot(proof, receipt)
        check(snapshot == proof.get("modelExecution"), "review model provenance changed")
        if snapshot is not None:
            records.validate_review(json.loads(self.artifact(snapshot)), proof, receipt)
