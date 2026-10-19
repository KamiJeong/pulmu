"""Behavioral gate/worktree tests. All UI and review records here are synthetic."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / ".agents/skills/pulmu/scripts"


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.repo = self.directory / "repo"
        self.repo.mkdir()
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.invalid")
        (self.repo / "file.txt").write_text("base\n")
        self.git("add", ".")
        self.git("commit", "-m", "initial")
        self.shell("ignite.sh", "--type", "test", "--slug", "evidence", "Test evidence gates")
        self.metadata = self.repo / ".git/pulmu-metadata"
        self.run_id = (self.metadata / "run_id").read_text().strip()
        self.store = self.repo / ".git/pulmu/evidence" / self.run_id
        self.context("set-stage", "inspect")
        self.context("set-stage", "shape")
        self.meta("finalize", "--type", "test", "--forge", "quick", "--risk", "low", "--areas", "testing",
                  "--pattern", "false", "--execution", "direct", "--writer", "orchestrator", "--review-mode", "self",
                  "--test-review", "false", "--security-review", "false", "--compatibility-review", "false")

    def call(self, args, ok=True, cwd=None):
        result = subprocess.run(args, cwd=cwd or self.repo, text=True, capture_output=True)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def git(self, *args):
        return self.call(["git", *args]).stdout.strip()

    def shell(self, script, *args, ok=True):
        return self.call(["bash", str(SCRIPTS / script), *args], ok=ok)

    def context(self, *args, ok=True):
        return self.shell("run-context.sh", *args, "--expect-run-id", self.run_id, ok=ok)

    def meta(self, *args, ok=True):
        return self.shell("metadata.sh", *args, "--expect-run-id", self.run_id, ok=ok)

    def save(self, name, value):
        path = self.directory / name
        path.write_text(json.dumps(value))
        return str(path)

    def shape(self, surface=None):
        scenarios = [{"id": "submit", "surface": surface, "steps": ["Submit the form"],
                      "expected": "Saved", "viewport": "390x844"}] if surface else []
        contract = {"acceptance": ["Validate test fixture"], "boundaries": ["Temporary files only"],
                    "clarifications": [{"answer": "Use test fixture", "source": "test case"}],
                    "assumptions": [], "patternBrief": "",
                    "ui": {"required": bool(scenarios), "reason": "Synthetic test scope", "scenarios": scenarios}}
        self.meta("shape", "--file", self.save("shape.json", contract))
        self.meta("verification", "--check", ".", "git diff --check")

    def quench_stage(self, surface=None):
        self.shape(surface)
        self.context("set-stage", "hammer")
        (self.repo / "file.txt").write_text("candidate\n")
        self.context("set-stage", "quench")

    def candidate(self):
        return json.loads(self.context("candidate").stdout)

    def ui(self, result="pass", **changes):
        value = {**self.candidate(), "scenario": "submit", "tool": "synthetic-tool", "toolCall": "test-call",
                 "target": "fixture-only", "steps": ["Submit the form"], "observed": "Saved",
                 "result": result, "limitations": "Synthetic gate test, not UI execution",
                 "artifacts": [self.save("trace.json", {"synthetic": True})]}
        value.update(changes)
        return self.save("ui.json", value)

    def run_quench(self, ok=True):
        return self.shell("quench.sh", "--expect-run-id", self.run_id, ok=ok)

    def review(self, provenance=True, wrong_result=False, ok=True):
        candidate = (self.metadata / "quench_fingerprint").read_text().strip()
        role = "pulmu_self_review"
        self.meta("review-attempt", "--role", role, "--candidate", candidate)
        result = {"runId": self.run_id, "candidate": candidate, "role": role, "completion": "complete",
                  "severity": "none", "findings": "PASS", "evidence": "Synthetic fixture inspected", "limitations": "Synthetic"}
        original = {**result, "severity": "high"} if wrong_result else result
        proof = {"executionId": "fixture-main", "contextMode": "self",
                 "input": self.save("dispatch.json", {"runId": self.run_id, "candidate": candidate}),
                 "result": self.save("result.json", original)}
        if provenance and (self.metadata / "version").read_text().strip() == "3":
            record = self.start_agent(role=role, execution="fixture-main", brief=proof["input"])
            self.finish_agent(record, result=proof["result"])
            proof["invocationId"] = record["invocationId"]
        args = ["review"]
        for key in ("role", "candidate", "completion", "severity", "findings", "evidence", "limitations"):
            args += ["--" + key, result[key]]
        if provenance:
            args += ["--provenance", self.save("proof.json", proof)]
        self.meta(*args, ok=ok)

    def approved(self, surface=None):
        self.quench_stage(surface)
        if surface:
            self.meta("ui", "--file", self.ui())
        self.run_quench()
        self.context("set-stage", "hone")
        self.review()
        self.meta("hone", "--result", "pass")
        self.meta("delivery", "--title", "test: evidence fixture", "--summary", "Exercise assurance",
                  "--change", "Change fixture")

    def test_missing_shape_blocks_hammer(self):
        self.meta("verification", "--check", ".", "git diff --check")
        self.context("set-stage", "hammer", ok=False)

    def start_agent(self, role="pulmu_architect", profile="default", execution="runtime-thread", brief=None, ok=True):
        agent_type = "orchestrator" if role == "pulmu_self_review" else role + ("_high" if profile == "high" else "")
        value = {"executionId": execution, "role": role, "profile": profile, "agentType": agent_type,
                 "reason": "Synthetic independent question", "brief": brief or self.save("brief.json", {"synthetic": True})}
        output = self.context("agent-record", "start", "--file", self.save("start.json", value), ok=ok)
        return json.loads(output.stdout) if ok else output

    def finish_agent(self, record, model=None, effort=None, result=None, status="completed", ok=True, source=None):
        if source is None and (model is not None or effort is not None):
            source = self.save("runtime.json", {"executionId": record["executionId"], "model": model, "effort": effort,
                                                "synthetic": True})
        value = {"invocationId": record["invocationId"], "status": status, "summary": "Synthetic outcome",
                 "result": result or self.save("outcome.json", {"synthetic": True}),
                 "observed": {"model": model, "effort": effort, "source": source,
                              "limitations": "Synthetic runtime metadata; no real model execution"}}
        output = self.context("agent-record", "finish", "--file", self.save("finish.json", value), ok=ok)
        return json.loads(output.stdout) if ok else output

    def independent_hone(self):
        self.context("replan", "--reason", "Independent review fixture")
        self.meta("finalize", "--type", "test", "--forge", "standard", "--risk", "medium", "--areas", "testing",
                  "--pattern", "false", "--execution", "reviewed", "--writer", "orchestrator", "--review-mode", "independent",
                  "--test-review", "false", "--security-review", "false", "--compatibility-review", "false")
        self.quench_stage()
        self.run_quench()
        self.context("set-stage", "hone")

    def recorded_review(self, model=None, effort=None, ok=True):
        candidate = (self.metadata / "quench_fingerprint").read_text().strip()
        role = "pulmu_reviewer"
        result = {"runId": self.run_id, "candidate": candidate, "role": role, "completion": "complete",
                  "severity": "none", "findings": "PASS", "evidence": "Synthetic fixture", "limitations": "Synthetic"}
        brief = self.save("review-brief.json", {"candidate": candidate})
        original = self.save("review-original.json", result)
        self.meta("review-attempt", "--role", role, "--candidate", candidate)
        record = self.start_agent(role=role, brief=brief)
        record = self.finish_agent(record, model=model, effort=effort, result=original)
        proof = {"executionId": record["executionId"], "invocationId": record["invocationId"], "contextMode": "fresh",
                 "input": brief, "result": original}
        args = ["review", "--provenance", self.save("recorded-proof.json", proof)]
        for key in ("role", "candidate", "completion", "severity", "findings", "evidence", "limitations"):
            args += ["--" + key, result[key]]
        self.meta(*args, ok=ok)
        return record

    def test_profiles_preserve_canonical_roles_and_reject_unsupported_escalation(self):
        output = self.shell("run-context.sh", "agent-profile", "--role", "pulmu_smith", "--profile", "high")
        value = json.loads(output.stdout)
        self.assertEqual(value["role"], "pulmu_smith")
        self.assertEqual(value["agentType"], "pulmu_smith_high")
        self.assertEqual(value["requested"], {"model": "gpt-6.1-sol", "effort": "high"})
        self.shell("run-context.sh", "agent-profile", "--role", "pulmu_explorer", "--profile", "high", ok=False)

    def test_agent_records_do_not_infer_effective_settings_and_keep_reused_threads(self):
        first = self.start_agent()
        self.start_agent(ok=False)
        final = self.finish_agent(first)
        self.assertEqual(final["requested"]["model"], "gpt-6.1-sol")
        self.assertIsNone(final["observed"]["model"])
        self.finish_agent(first, ok=False)
        second = self.start_agent()
        self.assertNotEqual(first["invocationId"], second["invocationId"])
        self.finish_agent(second, status="interrupted")
        self.assertEqual(len(list((self.store / "agents").glob("*.json"))), 2)

    def test_agent_runtime_source_must_match_execution_and_observation(self):
        record = self.start_agent()
        wrong = self.save("wrong-runtime.json", {"executionId": "another-thread", "model": "gpt-6.1-sol", "effort": "high"})
        self.finish_agent(record, model="gpt-6.1-sol", effort="high", source=wrong, ok=False)
        wrong = self.save("wrong-runtime.json", {"executionId": record["executionId"], "model": "gpt-6.1-sol", "effort": "medium"})
        self.finish_agent(record, model="gpt-6.1-sol", effort="high", source=wrong, ok=False)
        final = self.finish_agent(record, model="gpt-6.1-sol", effort="high")
        self.assertEqual(final["observed"]["effort"], "high")
        (self.store / "artifacts" / final["observed"]["source"]).write_text("corrupt")
        self.start_agent(ok=False)

    def test_stage_and_run_guard_agent_dispatch_and_allow_interrupt_cleanup(self):
        self.start_agent(role="pulmu_smith", ok=False)
        self.context("set-agents", "pulmu_smith_high", ok=False)
        record = self.start_agent()
        self.context("interrupt", "--message", "test interruption")
        self.start_agent(execution="new-thread", ok=False)
        self.finish_agent(record, status="interrupted")

    def test_review_records_unknown_models_without_claiming_confirmation(self):
        self.independent_hone()
        self.recorded_review()
        self.meta("hone", "--result", "pass")
        output = self.context("evidence-summary").stdout
        self.assertIn("observed unknown/unknown; unverified", output)
        receipt = json.loads((self.repo / ".git/pulmu-reviews/pulmu_reviewer.json").read_text())
        self.assertTrue(receipt["provenance"]["modelExecution"])

    def test_known_reviewer_profile_downgrade_blocks_approval(self):
        self.independent_hone()
        self.recorded_review(model="gpt-6.1-sol", effort="medium", ok=False)
        self.meta("hone", "--result", "pass", ok=False)
        self.assertIn("mismatch", self.context("evidence-summary").stdout)

    def test_model_provenance_is_revalidated_after_hone(self):
        self.independent_hone()
        record = self.recorded_review(model="gpt-6.1-sol", effort="high")
        self.meta("hone", "--result", "pass")
        self.assertIn("runtime-reported", self.context("evidence-summary").stdout)
        path = self.store / "agents" / (record["invocationId"] + ".json")
        wrapper = json.loads(path.read_text())
        wrapper["record"]["requested"]["effort"] = "medium"
        path.write_text(json.dumps(wrapper))
        self.context("set-stage", "ship", ok=False)

    def test_legacy_provenance_remains_model_unverified(self):
        (self.metadata / "version").write_text("2\n")
        self.approved()
        self.assertIn("models: unverified", self.context("evidence-summary").stdout)

    def test_unrecorded_execution_cannot_bypass_model_mismatch(self):
        self.independent_hone()
        self.recorded_review(model="gpt-6.1-sol", effort="medium", ok=False)
        result = json.loads((self.directory / "review-original.json").read_text())
        proof = json.loads((self.directory / "recorded-proof.json").read_text())
        proof["executionId"] = "unrecorded-thread"
        del proof["invocationId"]
        args = ["review", "--provenance", self.save("bypass-proof.json", proof)]
        for key in ("role", "candidate", "completion", "severity", "findings", "evidence", "limitations"):
            args += ["--" + key, result[key]]
        self.meta(*args, ok=False)
        self.meta("hone", "--result", "pass", ok=False)

    def test_reviewer_cannot_reuse_architect_execution(self):
        record = self.start_agent(execution="reused-thread")
        self.finish_agent(record)
        self.independent_hone()
        self.meta("review-attempt", "--role", "pulmu_reviewer", "--candidate", self.candidate()["candidate"])
        self.start_agent(role="pulmu_reviewer", execution="reused-thread", ok=False)

    def test_same_candidate_transport_repair_is_bounded_and_keeps_execution(self):
        self.independent_hone()
        candidate = self.candidate()["candidate"]
        self.meta("review-attempt", "--role", "pulmu_reviewer", "--candidate", candidate)
        first = self.start_agent(role="pulmu_reviewer")
        self.finish_agent(first, status="failed")
        self.start_agent(role="pulmu_reviewer", ok=False)
        self.meta("review-attempt", "--role", "pulmu_reviewer", "--candidate", candidate)
        repair = self.start_agent(role="pulmu_reviewer")
        self.assertEqual(repair["repairOf"], first["invocationId"])
        self.finish_agent(repair, status="failed")
        self.start_agent(role="pulmu_reviewer", ok=False)
        self.meta("review-attempt", "--role", "pulmu_reviewer", "--candidate", candidate, ok=False)

    def repaired_review(self, severity="high", changes=None, opaque=False, fresh=False, ok=True):
        self.independent_hone()
        candidate = self.candidate()["candidate"]
        role = "pulmu_reviewer"
        brief = self.save("repair-brief.json", {"candidate": candidate})
        original = {"role": role, "runId": self.run_id, "candidate": candidate,
                    "completion": "complete", "severity": severity,
                    "findings": "Authorization bypass" if severity == "high" else "PASS",
                    "evidence": "Synthetic fixture inspected"}
        # The required limitations field is absent: repair must add it while
        # preserving the substantive verdict already delivered.
        original_path = self.save("malformed-review.json", original)
        if opaque:
            Path(original_path).write_text('{"severity": "high",')
        self.meta("review-attempt", "--role", role, "--candidate", candidate)
        first = self.start_agent(role=role, brief=brief)
        self.finish_agent(first, status="failed", result=original_path)
        self.meta("review-attempt", "--role", role, "--candidate", candidate)
        repair = self.start_agent(role=role, brief=brief, execution="fresh-repair-thread" if fresh else "runtime-thread")
        self.assertEqual(repair["repairOf"], None if fresh else first["invocationId"])
        fixed = {**original, "limitations": "Synthetic", **(changes or {})}
        result_path = self.save("repaired-review.json", fixed)
        self.finish_agent(repair, result=result_path)
        proof = {"executionId": repair["executionId"], "invocationId": repair["invocationId"],
                 "contextMode": "fresh", "input": brief, "result": result_path}
        args = ["review", "--provenance", self.save("repair-proof.json", proof)]
        for key in ("role", "candidate", "completion", "severity", "findings", "evidence", "limitations"):
            args += ["--" + key, fixed[key]]
        output = self.meta(*args, ok=ok)
        self.assertEqual(self.candidate()["candidate"], candidate)
        return output

    def test_format_repair_cannot_downgrade_blocking_verdict(self):
        output = self.repaired_review(changes={"severity": "none", "findings": "PASS"}, ok=False)
        self.assertIn("repair changed substantive severity", output.stderr)
        self.meta("hone", "--result", "pass", ok=False)

    def test_format_repair_cannot_replace_findings_at_same_severity(self):
        output = self.repaired_review(changes={"findings": "Different finding"}, ok=False)
        self.assertIn("repair changed substantive findings", output.stderr)

    def test_fresh_execution_repair_cannot_discard_blocking_verdict(self):
        output = self.repaired_review(fresh=True, changes={"severity": "none", "findings": "PASS"}, ok=False)
        self.assertIn("repair changed substantive severity", output.stderr)
        self.meta("hone", "--result", "pass", ok=False)

    def test_format_repair_preserves_blocking_verdict(self):
        self.repaired_review()
        self.meta("hone", "--result", "pass", ok=False)

    def test_format_repair_can_complete_a_passing_result(self):
        self.repaired_review(severity="none", fresh=True)
        self.meta("hone", "--result", "pass")

    def test_format_repair_cannot_approve_an_unreadable_original(self):
        output = self.repaired_review(opaque=True, changes={"severity": "none", "findings": "PASS"}, ok=False)
        self.assertIn("cannot verify original repair verdict", output.stderr)
        self.meta("hone", "--result", "pass", ok=False)

    def test_fresh_thread_cannot_bypass_review_attempt_budget(self):
        self.independent_hone()
        candidate = self.candidate()["candidate"]
        self.meta("review-attempt", "--role", "pulmu_reviewer", "--candidate", candidate)
        first = self.start_agent(role="pulmu_reviewer", execution="thread-one")
        self.finish_agent(first, status="failed")
        self.start_agent(role="pulmu_reviewer", execution="thread-two", ok=False)
        self.meta("review-attempt", "--role", "pulmu_reviewer", "--candidate", candidate)
        second = self.start_agent(role="pulmu_reviewer", execution="thread-two")
        self.finish_agent(second, status="failed")
        self.start_agent(role="pulmu_reviewer", execution="thread-three", ok=False)

    def test_identical_candidate_can_be_reviewed_after_explicit_retry(self):
        self.independent_hone()
        first = self.recorded_review()
        self.context("increment-retry", "hone")
        self.context("set-stage", "hammer")
        self.context("set-stage", "quench")
        self.run_quench()
        self.context("set-stage", "hone")
        candidate = self.candidate()["candidate"]
        self.assertEqual(first["candidate"], candidate)
        self.meta("review-attempt", "--role", "pulmu_reviewer", "--candidate", candidate)
        second = self.start_agent(role="pulmu_reviewer", execution="fresh-after-retry")
        self.assertNotEqual(first["reviewGroup"], second["reviewGroup"])

    def test_smith_profiles_cannot_run_concurrently(self):
        self.context("replan", "--reason", "Delegated writer fixture")
        self.meta("finalize", "--type", "test", "--forge", "standard", "--risk", "medium", "--areas", "testing",
                  "--pattern", "false", "--execution", "delegated", "--writer", "pulmu_smith", "--review-mode", "independent",
                  "--test-review", "false", "--security-review", "false", "--compatibility-review", "false")
        self.shape()
        self.context("set-stage", "hammer")
        first = self.start_agent(role="pulmu_smith", execution="writer-one")
        self.start_agent(role="pulmu_smith", profile="high", execution="writer-two", ok=False)
        self.finish_agent(first, status="interrupted")
        second = self.start_agent(role="pulmu_smith", profile="high", execution="writer-two")
        self.assertEqual(second["requested"]["effort"], "high")

    def test_profiles_and_context_work_without_tomllib(self):
        import sys
        script = '''
import builtins, runpy, sys
original = builtins.__import__
def no_tomllib(name, *args, **kwargs):
    if name == "tomllib":
        raise ModuleNotFoundError("Python 3.10 has no tomllib")
    return original(name, *args, **kwargs)
builtins.__import__ = no_tomllib
sys.argv = [sys.argv[1], "agent-profile", "--role", "pulmu_test_reviewer", "--profile", "high"]
runpy.run_path(sys.argv[0], run_name="__main__")
'''
        output = self.call([sys.executable, "-c", script, str(SCRIPTS / "run-context.py")])
        self.assertEqual(json.loads(output.stdout)["requested"]["effort"], "high")

    def test_missing_version_cannot_downgrade_assurance(self):
        self.meta("verification", "--check", ".", "git diff --check")
        (self.metadata / "version").unlink()
        self.context("set-stage", "hammer", ok=False)

    def test_recorded_ui_observation_cannot_be_rewritten(self):
        self.quench_stage("browser")
        self.meta("ui", "--file", self.ui())
        path = self.store / "ui/submit.json"
        receipt = json.loads(path.read_text())
        receipt["buildTree"] = "0" * 40
        for key in ("tool", "toolCall", "target", "steps", "observed", "limitations"):
            del receipt[key]
        path.write_text(json.dumps(receipt))
        self.run_quench(ok=False)

    def test_failed_log_cannot_publish_quench_pass(self):
        self.quench_stage()
        identity = self.candidate()
        self.context("quench-evidence", "begin", "--attempt", "failed-log-attempt")
        log = self.directory / "failed.log"
        log.write_bytes(b"\xff\nPULMU_QUENCH_CHECK_EXIT=git diff --check:1\nPULMU_QUENCH=FAIL\n")
        self.context("quench-evidence", "pass", "--attempt", "failed-log-attempt", "--branch", "test/evidence",
                     "--base", "main", "--base-head", self.git("rev-parse", "main"), "--head", self.git("rev-parse", "HEAD"),
                     "--tree", identity["buildTree"], "--fingerprint", identity["candidate"], "--log", str(log), ok=False)
        self.assertFalse((self.metadata / "quench_fingerprint").exists())

    def test_quench_preserves_non_utf8_output_with_unicode_check_label(self):
        self.shape()
        self.meta("verification", "--check", ".", "printf '검증\\377'; exit 0")
        self.context("set-stage", "hammer")
        (self.repo / "file.txt").write_text("candidate\n")
        self.context("set-stage", "quench")
        result = subprocess.run(["bash", str(SCRIPTS / "quench.sh"), "--expect-run-id", self.run_id],
                                cwd=self.repo, capture_output=True)
        self.assertEqual(result.returncode, 0, repr(result.stderr))
        self.assertIn(b"PULMU_QUENCH=PASS", result.stdout)
        log = (self.repo / ".git/pulmu-quench.log").read_bytes()
        self.assertIn("검증".encode("utf-8") + b"\xff", log)
        self.assertEqual((self.metadata / "quench_fingerprint").read_text().strip(), self.candidate()["candidate"])
        self.context("set-stage", "hone")

    def test_sealed_intent_and_plan_cannot_drift(self):
        self.quench_stage()
        (self.metadata / "verification-plan").write_text("true\t.\ttrue\n")
        self.run_quench(ok=False)
        self.assertFalse((self.metadata / "quench_fingerprint").exists())

    def test_ui_requires_execution_and_preserved_artifacts(self):
        for surface in ("browser", "native"):
            with self.subTest(surface=surface):
                if surface == "native":
                    self.context("replan", "--reason", "Test native surface")
                    self.meta("finalize", "--type", "test", "--forge", "quick", "--risk", "low", "--areas", "testing",
                              "--pattern", "false", "--execution", "direct", "--writer", "orchestrator", "--review-mode", "self",
                              "--test-review", "false", "--security-review", "false", "--compatibility-review", "false")
                self.quench_stage(surface)
                self.run_quench(ok=False)
                self.meta("ui", "--file", self.ui("blocked"))
                self.run_quench(ok=False)
                self.meta("ui", "--file", self.ui(artifacts=[]), ok=False)
                self.meta("ui", "--file", self.ui(candidate="0" * 40), ok=False)
                self.meta("ui", "--file", self.ui(runId="another-run"), ok=False)
                self.meta("ui", "--file", self.ui(buildTree="0" * 40), ok=False)
                self.meta("ui", "--file", self.ui())
                (self.directory / "trace.json").unlink()
                self.run_quench()
                receipt = json.loads((self.store / "ui/submit.json").read_text())
                (self.store / "artifacts" / receipt["artifacts"][0]).write_text("tampered")
                self.context("set-stage", "hone", ok=False)

    def test_retry_invalidates_same_candidate_ui_and_preserves_intent(self):
        self.quench_stage("browser")
        self.meta("ui", "--file", self.ui())
        original = (self.store / "shape.json").read_bytes()
        self.run_quench()
        self.context("increment-retry", "quench")
        self.context("set-stage", "quench")
        self.run_quench(ok=False)
        self.assertEqual((self.store / "shape.json").read_bytes(), original)
        self.context("replan", "--reason", "New accepted requirement")
        self.assertFalse((self.store / "shape.json").exists())
        self.assertTrue(list((self.store / "contracts").glob("*.json")))

    def test_absent_provenance_blocks_review(self):
        self.quench_stage()
        self.run_quench()
        self.context("set-stage", "hone")
        self.review(provenance=False, ok=False)
        self.meta("hone", "--result", "pass", ok=False)

    def test_changed_original_verdict_blocks_review(self):
        self.quench_stage()
        self.run_quench()
        self.context("set-stage", "hone")
        self.review(wrong_result=True, ok=False)

    def test_source_artifact_is_rechecked_at_ship(self):
        self.approved()
        receipt = json.loads((self.repo / ".git/pulmu-reviews/pulmu_self_review.json").read_text())
        (self.store / "artifacts" / receipt["provenance"]["result"]).write_text("tampered")
        head = self.git("rev-parse", "HEAD")
        self.shell("ship.sh", "--delivery", "local", "--expect-run-id", self.run_id, ok=False)
        self.assertEqual(self.git("rev-parse", "HEAD"), head)

    def test_ui_evidence_survives_local_ship_but_not_reverification(self):
        self.approved("browser")
        self.context("set-stage", "ship")
        self.git("add", ".")
        self.git("commit", "-m", "test: pending delivery")
        self.context("reverify-ship", "--commit", self.git("rev-parse", "HEAD"))
        self.run_quench(ok=False)
        self.meta("ui", "--file", self.ui())
        self.run_quench()
        self.context("set-stage", "hone")
        self.review()
        self.meta("hone", "--result", "pass")
        self.meta("delivery", "--title", "test: evidence fixture", "--summary", "Exercise assurance", "--change", "Change fixture")
        output = self.shell("ship.sh", "--delivery", "local", "--expect-run-id", self.run_id).stdout
        self.assertIn("Required browser/native scenarios: 1", output)
        self.assertEqual(json.loads((self.repo / ".git/pulmu/run.json").read_text())["status"], "completed")

    def test_ship_resume_rejects_advanced_base_and_can_reverify(self):
        self.approved()
        self.context("set-stage", "ship")
        self.git("add", ".")
        self.git("commit", "-m", "test: pending delivery")
        head = self.git("rev-parse", "HEAD")
        advanced = self.git("commit-tree", self.git("rev-parse", "main^{tree}"), "-p", "main", "-m", "Advance base")
        self.git("update-ref", "refs/heads/main", advanced)
        self.context("validate-ship", "--commit", head, ok=False)
        self.context("reverify-ship", "--commit", head)
        self.assertEqual(self.git("rev-parse", "HEAD"), head)
        self.assertFalse((self.metadata / "hone_fingerprint").exists())
        self.run_quench()

    def test_legacy_evidence_is_not_upgraded(self):
        (self.metadata / "version").write_text("1\n")
        self.meta("verification", "--check", ".", "git diff --check")
        self.context("set-stage", "hammer")
        (self.repo / "file.txt").write_text("legacy\n")
        self.context("set-stage", "quench")
        self.run_quench()
        self.context("set-stage", "hone")
        self.review(provenance=False)
        self.meta("hone", "--result", "pass")
        summary = self.context("evidence-summary").stdout
        self.assertIn("legacy", summary)
        self.assertFalse(self.store.exists())

    def test_parallel_worktrees_preserve_parent_and_isolate_state(self):
        parent_state = (self.repo / ".git/pulmu/run.json").read_bytes()
        (self.repo / "file.txt").write_text("unrelated user edits\n")
        targets = [self.directory / "issue-a", self.directory / "issue-b"]
        jobs = [subprocess.Popen(["bash", str(SCRIPTS / "ignite.sh"), "--worktree", str(target),
                                 "--base", "main", "--type", "test", "--slug", "same-issue", "Independent issue"],
                                cwd=self.repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                for target in targets]
        for job in jobs:
            output, error = job.communicate(timeout=30)
            self.assertEqual(job.returncode, 0, output + error)
        self.assertEqual((self.repo / ".git/pulmu/run.json").read_bytes(), parent_state)
        self.assertEqual((self.repo / "file.txt").read_text(), "unrelated user edits\n")
        states = []
        for target in targets:
            self.assertEqual((target / "file.txt").read_text(), "base\n")
            git_dir = Path(self.call(["git", "rev-parse", "--absolute-git-dir"], cwd=target).stdout.strip())
            states.append(json.loads((git_dir / "pulmu/run.json").read_text()))
        self.assertNotEqual(states[0]["runId"], states[1]["runId"])
        self.assertNotEqual(states[0]["git"]["branch"], states[1]["git"]["branch"])
        listing = json.loads(self.call(["python3", str(SCRIPTS / "worktrees.py"), "list"]).stdout)
        self.assertEqual(len(listing), 3)
        self.shell("ignite.sh", "--worktree", str(targets[0]), "Existing destination", ok=False)
        self.shell("ignite.sh", "--worktree", str(self.repo / "nested"), "Nested destination", ok=False)
        self.shell("ignite.sh", "--worktree", str(targets[0] / "nested"), "Nested sibling destination", ok=False)
        self.assertEqual(self.call(["git", "status", "--porcelain"], cwd=targets[0]).stdout, "")


if __name__ == "__main__":
    unittest.main()
