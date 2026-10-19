"""Synthetic gate fixtures, never evidence of real browser or model execution."""

import json
from pathlib import Path
import subprocess
import sys


action, root, *arguments = sys.argv[1:]
scripts = Path(root) / ".agents/skills/pulmu/scripts"
git_dir = Path(subprocess.check_output(["git", "rev-parse", "--absolute-git-dir"], text=True).strip())
metadata = git_dir / "pulmu-metadata"
run_id = (metadata / "run_id").read_text().strip()
state = json.loads((git_dir / "pulmu/run.json").read_text())
evidence = git_dir / "pulmu/evidence" / run_id


def command(name, *args):
    return subprocess.check_output([sys.executable, str(scripts / "run-context.py"), name,
                                    *args, "--expect-run-id", run_id], text=True)


def save(name, value):
    path = git_dir / name
    path.write_text(json.dumps(value))
    return str(path)


if action == "shape":
    if (metadata / "version").read_text().strip() not in {"2", "3"} or (evidence / "seal.json").exists():
        raise SystemExit(0)
    scenarios = [{"id": "fixture-view", "surface": "browser", "steps": ["Synthetic observation"],
                  "expected": "Synthetic gate accepts fixture", "viewport": "fixture"}] if state["pattern"] else []
    shape = {"acceptance": ["Exercise deterministic fixture behavior"], "boundaries": ["Temporary repository only"],
             "clarifications": [], "assumptions": [], "patternBrief": "Synthetic fixture design" if scenarios else "",
             "ui": {"required": bool(scenarios), "reason": "Synthetic receipt test only", "scenarios": scenarios}}
    print(command("shape-contract", "--file", save("fixture-shape.json", shape)))
elif action == "ui":
    if not (evidence / "shape.json").exists():
        raise SystemExit(0)
    shape = json.loads((evidence / "shape.json").read_text())["contract"]
    candidate = json.loads(command("candidate"))
    artifact = save("fixture-ui-output.json", {"synthetic": True})
    for scenario in shape["ui"]["scenarios"]:
        receipt = {**candidate, "scenario": scenario["id"], "tool": "synthetic-test", "toolCall": "fixture-call",
                   "target": "fixture-only", "steps": ["Synthetic observation"], "observed": "Synthetic pass",
                   "result": "pass", "limitations": "Not actual UI execution", "artifacts": [artifact]}
        print(command("ui-result", "--file", save("fixture-ui.json", receipt)))
elif action == "review":
    values = dict(zip(arguments[::2], arguments[1::2]))
    role = values["--role"]
    result = {"runId": run_id, **{key: values.get("--" + key, "none") for key in
              ("role", "candidate", "completion", "severity", "findings", "evidence", "limitations")}}
    original = save("fixture-review-result.json", result)
    brief = save("fixture-review-input.json", {"runId": run_id, "candidate": result["candidate"], "synthetic": True})
    proof = {"executionId": "fixture-" + role, "contextMode": "self" if role == "pulmu_self_review" else "fresh",
             "input": brief, "result": original}
    if (metadata / "version").read_text().strip() == "3":
        import secrets
        proof["executionId"] += "-" + secrets.token_hex(8)
        started = json.loads(command("agent-record", "start", "--file", save("fixture-start.json", {
            "executionId": proof["executionId"], "role": role, "profile": "default",
            "agentType": "orchestrator" if role == "pulmu_self_review" else role,
            "reason": "Synthetic fixture only", "brief": brief})))
        proof["invocationId"] = started["invocationId"]
        command("agent-record", "finish", "--file", save("fixture-finish.json", {
            "invocationId": started["invocationId"], "status": "completed", "summary": "Synthetic fixture only",
            "result": original, "observed": {"model": None, "effort": None, "source": None,
                                             "limitations": "No model executed; synthetic gate test"}}))
    print(save("fixture-provenance.json", proof))
