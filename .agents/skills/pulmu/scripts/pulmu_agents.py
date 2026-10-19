"""Recorded agent dispatches; runtime reports are evidence, not authentication."""

from __future__ import annotations

import datetime as dt
import json
from pathlib import Path
import secrets
import re

from pulmu_evidence import atomic, check, encoded, private_directory, read_bytes, read_json, text


ROLES = {
    "pulmu_explorer", "pulmu_test_scout", "pulmu_risk_scout", "pulmu_architect",
    "pulmu_designer", "pulmu_smith", "pulmu_failure_analyst", "pulmu_reviewer",
    "pulmu_test_reviewer", "pulmu_security_reviewer", "pulmu_compat_reviewer",
    "pulmu_design_reviewer", "pulmu_self_review",
}
HIGH_PROFILES = {"pulmu_smith", "pulmu_test_reviewer"}
EFFORTS = {"none", "low", "medium", "high", "xhigh", "max"}


def canonical_role(name):
    return name[:-5] if name.endswith("_high") and name[:-5] in HIGH_PROFILES else name


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def profile_header(contents):
    """Read shipped scalar headers on Python 3.10; never infer missing values.

    This is deliberately not a general TOML parser. Profile scalars precede the
    developer_instructions body and use ordinary quoted strings. Runtime loading
    remains authoritative for the complete custom-agent TOML.
    """
    values = {}
    keys = {"name", "model", "model_reasoning_effort"}
    for line in contents.splitlines():
        if re.match(r"\s*developer_instructions\s*=", line):
            break
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        match = re.fullmatch(r'''\s*(name|model|model_reasoning_effort)\s*=\s*("(?:[^"\\]|\\.)*"|'[^']*')\s*(?:#.*)?''', line)
        if match:
            key, value = match.groups()
            check(key not in values, f"duplicate agent profile {key}")
            values[key] = json.loads(value) if value.startswith('"') else value[1:-1]
        elif re.match(r"\s*(name|model|model_reasoning_effort)\s*=", line) or line.lstrip().startswith("["):
            check(False, "unsupported agent profile header; use bundled quoted scalar format")
    check(set(values) == keys, "missing agent profile header fields")
    return values


def profile(role, level):
    check(isinstance(role, str) and isinstance(level, str) and role in ROLES and level in {"default", "high"}, "unknown agent role/profile")
    check(level != "high" or role in HIGH_PROFILES, "role has no high profile")
    if role == "pulmu_self_review":
        return {"role": role, "profile": level, "agentType": "orchestrator",
                "requested": {"model": None, "effort": None}, "config": None}
    agent_type = role + ("_high" if level == "high" else "")
    # Both supported install scopes place agents next to .agents in .codex.
    path = Path(__file__).resolve().parents[4] / ".codex/agents" / (agent_type.replace("_", "-") + ".toml")
    try:
        config = profile_header(read_bytes(path).decode())
    except (ValueError, UnicodeError):
        check(False, f"invalid agent profile: {path}")
    check(config.get("name") == agent_type, "agent profile name mismatch")
    text(config.get("model"), "configured model")
    check(isinstance(config.get("model_reasoning_effort"), str)
          and config["model_reasoning_effort"] in EFFORTS, "invalid configured effort")
    return {"role": role, "profile": level, "agentType": agent_type,
            "requested": {"model": config["model"], "effort": config["model_reasoning_effort"]},
            "config": str(path)}


class AgentRecords:
    def __init__(self, evidence):
        self.evidence = evidence
        self.root = evidence.root / "agents"
        check(not self.root.is_symlink(), "agent records directory is symlinked")

    def path(self, invocation):
        import re
        check(isinstance(invocation, str) and re.fullmatch(r"call-[a-f0-9]{24}", invocation), "invalid invocation ID")
        return self.root / (invocation + ".json")

    def save(self, record):
        self.evidence.prepare()
        private_directory(self.root)
        source = self.evidence.capture_bytes(encoded(record))
        atomic(self.path(record["invocationId"]), encoded({"record": record, "source": source}))
        return record

    def load(self, path):
        wrapper = read_json(path)
        check(isinstance(wrapper, dict) and set(wrapper) == {"record", "source"}, "invalid agent record")
        record = wrapper["record"]
        check(json.loads(self.evidence.artifact(wrapper["source"])) == record, "agent record changed")
        check(record["runId"] == self.evidence.state["runId"], "agent record belongs to another run")
        for key in ("brief", "config", "result"):
            if record[key] is not None:
                self.evidence.artifact(record[key])
        observed = record["observed"]
        if observed is not None and observed["source"] is not None:
            self.evidence.artifact(observed["source"])
        return record

    def records(self):
        return [self.load(path) for path in sorted(self.root.glob("call-*.json"))] if self.root.exists() else []

    def start(self, source, candidate, review_attempt=None, review_group=None):
        data = read_json(source)
        check(isinstance(data, dict) and set(data) == {"executionId", "role", "profile", "agentType", "reason", "brief"},
              "invalid agent start fields")
        for key in ("executionId", "reason"):
            text(data[key], key)
        selected = profile(data["role"], data["profile"])
        # A fresh default agent may carry the exact profile when the runtime
        # cannot discover a newly installed custom role. Never silently inherit.
        allowed = {selected["agentType"]} if data["role"] == "pulmu_self_review" else {selected["agentType"], "default"}
        check(data["agentType"] in allowed, "agent type conflicts with selected profile")
        previous = self.records()
        same_execution = [old for old in previous if old["executionId"] == data["executionId"]]
        repair_of = None
        for old in previous:
            if review_attempt is not None:
                check(not (old["role"] == data["role"] and old["candidate"] == candidate
                           and old.get("reviewGroup") == review_group and old.get("reviewAttempt") == review_attempt),
                      "review attempt already has an invocation")
            check(old["executionId"] != data["executionId"] or old["status"] != "running",
                  "execution already has a running invocation")
            if data["role"].endswith("reviewer"):
                if old["executionId"] == data["executionId"]:
                    repair = (review_attempt == 2 and len(same_execution) == 1
                              and old.get("reviewAttempt") == 1 and old["role"] == data["role"]
                              and old.get("reviewGroup") == review_group
                              and old["candidate"] == candidate and old["status"] in {"failed", "interrupted"}
                              and old["profile"] == data["profile"] and old["agentType"] == data["agentType"])
                    check(repair, "independent review requires a fresh execution except one same-candidate transport repair")
                    repair_of = old["invocationId"]
            if data["role"] == "pulmu_smith":
                check(old["role"] != "pulmu_smith" or old["status"] != "running",
                      "another Smith invocation is still running")
        record = {"schemaVersion": 1, "runId": self.evidence.state["runId"],
                  "invocationId": "call-" + secrets.token_hex(12), "executionId": data["executionId"],
                  "role": data["role"], "profile": data["profile"], "agentType": data["agentType"],
                  "requested": selected["requested"], "reason": data["reason"],
                  "stage": self.evidence.state["stage"]["current"], "candidate": candidate,
                  "reviewAttempt": review_attempt, "reviewGroup": review_group, "repairOf": repair_of,
                  "config": self.evidence.capture(selected["config"]) if selected["config"] else None,
                  "brief": self.evidence.capture(data["brief"]), "status": "running",
                  "startedAt": now(), "finishedAt": None, "summary": None, "result": None, "observed": None}
        return self.save(record)

    def finish(self, source):
        data = read_json(source)
        check(isinstance(data, dict) and set(data) == {"invocationId", "status", "summary", "result", "observed"},
              "invalid agent finish fields")
        record = self.load(self.path(data["invocationId"]))
        check(record["status"] == "running", "agent invocation is already final")
        check(isinstance(data["status"], str) and data["status"] in {"completed", "failed", "interrupted"}, "invalid agent outcome")
        text(data["summary"], "agent summary")
        check(data["status"] != "completed" or data["result"] is not None, "completed agent needs original result")
        observed = data["observed"]
        check(isinstance(observed, dict) and set(observed) == {"model", "effort", "source", "limitations"},
              "invalid observed model fields")
        text(observed["limitations"], "model observation limitations")
        if observed["model"] is not None:
            text(observed["model"], "observed model")
        check(observed["effort"] is None or (isinstance(observed["effort"], str)
              and observed["effort"] in EFFORTS), "invalid observed effort")
        known = observed["model"] is not None or observed["effort"] is not None
        check(known == (observed["source"] is not None), "known model/effort requires runtime source; unknown uses null")
        if known:
            runtime = read_json(observed["source"])
            check(isinstance(runtime, dict) and runtime.get("executionId") == record["executionId"],
                  "runtime source belongs to another execution")
            for key in ("model", "effort"):
                check(runtime.get(key) == observed[key], f"runtime source disagrees with observed {key}")
            observed = {**observed, "source": self.evidence.capture(observed["source"])}
        record.update(status=data["status"], summary=data["summary"], finishedAt=now(),
                      result=self.evidence.capture(data["result"]) if data["result"] is not None else None, observed=observed)
        return self.save(record)

    @staticmethod
    def assessment(record):
        actual = record["observed"] or {"model": None, "effort": None}
        expected = record["requested"]
        mismatch = [key for key in ("model", "effort") if actual[key] is not None
                    and expected[key] is not None and actual[key] != expected[key]]
        if mismatch:
            return "mismatch"
        if actual["model"] is None or actual["effort"] is None:
            return "unverified"
        return "runtime-reported"

    def review_snapshot(self, proof, receipt):
        matches = [record for record in self.records() if record["executionId"] == proof["executionId"]]
        if not matches:
            check(not self.evidence.models_required and not self.root.exists(), "review requires a recorded model invocation")
            return None  # Explicit old-format evidence has no model identity claim.
        matches = [r for r in matches if r["role"] == receipt["role"] and r["candidate"] == receipt["candidate"]]
        if proof.get("invocationId") is not None:
            matches = [r for r in matches if r["invocationId"] == proof["invocationId"]]
        check(len(matches) == 1, "review agent record is stale or ambiguous")
        record = matches[0]
        self.validate_review(record, proof, receipt)
        return self.evidence.capture_bytes(encoded(record))

    def validate_review(self, record, proof, receipt):
        check(record["runId"] == receipt["runId"] and record["executionId"] == proof["executionId"]
              and record["role"] == receipt["role"] and record["candidate"] == receipt["candidate"],
              "review model record identity mismatch")
        check(record["status"] == "completed", "review agent did not complete")
        check(record["reviewAttempt"] == receipt["submissions"] and record["reviewGroup"] == receipt.get("attemptGroup"),
              "model invocation belongs to a different review attempt")
        check(record["brief"] == proof["input"] and record["result"] == proof["result"],
              "review model record differs from original input/result")
        for key in ("brief", "result", "config"):
            if record[key] is not None:
                self.evidence.artifact(record[key])
        if record["observed"]["source"] is not None:
            self.evidence.artifact(record["observed"]["source"])
        check(self.assessment(record) != "mismatch", "observed reviewer model/effort differs from requested profile")
        self.validate_repair(record, receipt)

    def validate_repair(self, record, receipt):
        if record["reviewAttempt"] != 2:
            return
        # The second attempt is a format/transport repair even when it uses a
        # fresh execution. Thread freshness must not discard an earlier verdict.
        previous = [old for old in self.records() if old["reviewAttempt"] == 1
                    and all(old[key] == record[key] for key in ("role", "candidate", "reviewGroup"))]
        if not previous:
            check(record.get("repairOf") is None, "missing review repair origin")
            return  # The first attempt may have failed before dispatch.
        check(len(previous) == 1, "ambiguous review repair origin")
        prior = previous[0]
        check(prior["status"] in {"completed", "failed", "interrupted"}, "original review invocation is still running")
        if record.get("repairOf") is not None:
            check(record["repairOf"] == prior["invocationId"]
                  and prior["status"] in {"failed", "interrupted"}
                  and prior.get("repairOf") is None
                  and all(prior[key] == record[key] for key in ("executionId", "profile", "agentType")),
                  "invalid review repair origin")
        if prior["result"] is None:
            return  # A transport failure may not have delivered any verdict.
        try:
            original = json.loads(self.evidence.artifact(prior["result"]))
        except (ValueError, UnicodeError):
            check(False, "cannot verify original repair verdict; use an explicit Hone retry with fresh review")
        check(isinstance(original, dict), "cannot verify original repair verdict; use an explicit Hone retry with fresh review")
        # Preserve every usable substantive field, even when the first result
        # was rejected for missing/invalid fields elsewhere. Format repair is
        # not a second opinion on an unchanged candidate.
        preserved = {}
        for key, choices in (("completion", {"complete", "incomplete"}),
                             ("severity", {"none", "low", "medium", "high"})):
            value = original.get(key)
            if isinstance(value, str) and value in choices:
                preserved[key] = value
        for key in ("findings", "evidence", "limitations"):
            value = original.get(key)
            if isinstance(value, str) and value.strip():
                preserved[key] = value
        check(bool(preserved), "cannot verify original repair verdict; use an explicit Hone retry with fresh review")
        for key, value in preserved.items():
            check(receipt[key] == value, f"review format repair changed substantive {key}")
