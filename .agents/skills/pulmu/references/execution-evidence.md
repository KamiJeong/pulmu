# Durable intent and execution evidence

New Ignite runs use metadata format 3, independently of Run Context schema 2.
Format 3 requires reviewer invocation/model records, including explicit unknown
runtime settings. Existing format 2 retains intent/UI/review provenance without
retroactive model assurance; format 1 finishes with explicitly legacy assurance. Never manufacture new evidence for a previous run.

Evidence lives under `<resolved-git-dir>/pulmu/evidence/<runId>/`. Each linked
worktree has its own store. Artifact copies are private, content-addressed local
files; they are not uploaded to GitHub. Keep secrets and personal data out of
briefs, screenshots, transcripts, and original review outputs. Capture only what
the task needs, redact before submission, and preserve useful limitations.

## Shape contract

After finalizing routing and before Hammer, record a JSON file using
`metadata.sh shape --file <file> --expect-run-id "$RUN_ID"`. This is an internal
Orchestrator action, not another public command for the user. Resolve consequential
unknowns first; unresolved requirements cannot be replaced with assumptions.

```json
{
  "acceptance": ["An invalid profile name shows an inline error without saving"],
  "boundaries": ["Profile form and its validation only"],
  "clarifications": [{"answer": "Blank names are invalid", "source": "User reply in this task"}],
  "assumptions": ["Reuse the existing validation message style"],
  "patternBrief": "Reuse the form layout; focus the invalid input and announce the error",
  "ui": {
    "required": true,
    "reason": "The changed behavior is visible and interactive",
    "scenarios": [{
      "id": "invalid-name",
      "surface": "browser",
      "steps": ["Open the profile form", "Clear the name", "Submit with the keyboard"],
      "expected": "An inline error appears; no save request occurs; focus stays useful",
      "viewport": "390x844 and the supported desktop width"
    }]
  }
}
```

For non-UI work use `patternBrief: ""` and `ui: {"required": false, "reason":
"<specific reason>", "scenarios": []}`. Pattern requires actual UI scenarios.
Use `surface: "native"` for an app, simulator, or device; name its device/window
configuration in `viewport`. Split scenarios when separate evidence is needed.

Hammer seals both the Shape contract and finalized shell verification plan.
Later changes require explicit replan. Historical contracts are retained by
digest; replan clears the active contract and all downstream approval. Retries
preserve the contract but invalidate current UI/reviewer evidence. Read the saved
contract when resuming or handing work to a fresh agent, alongside accepted
conversation updates. Record new consequential answers through replan.

## Actual browser and app verification

During Inspect/Shape, identify the available browser/app automation tool, how to
launch the candidate build, and the test environment. Use the project's supported
browser runner, browser automation connector, native-app automation, or simulator
tool. Pulmu does not install a browser driver or provision accounts. If a required
tool, login, simulator, or service is unavailable, report the precise prerequisite;
do not treat a static mock, source-code review, or a written instruction as a UI pass.

During Quench, use those tools to perform each scenario on the candidate. Confirm
the running instance/build corresponds to this worktree (including a fresh build
or restart when needed), observe the outcome, and retain screenshots plus relevant
interaction/accessibility/network traces. Keyboard, focus, contrast, responsive
layout, and state claims each need appropriate observed evidence. A screenshot
alone does not establish working interactions. For parallel worktrees assign
distinct ports, browser profiles/app instances, and test data where needed.

Use `run-context.sh candidate --expect-run-id "$RUN_ID"` to obtain `runId`,
`candidate`, and `buildTree`. Record each actual observation with
`metadata.sh ui --file <receipt.json> --expect-run-id "$RUN_ID"`:

```json
{
  "runId": "<run ID>",
  "candidate": "<candidate fingerprint>",
  "buildTree": "<candidate Git tree>",
  "scenario": "invalid-name",
  "tool": "<actual browser/app tool>",
  "toolCall": "<actual tool call, trace, or session reference>",
  "target": "<tested URL/app instance, device and viewport>",
  "steps": ["<actions actually performed>"],
  "observed": "<actual result compared with the expected result>",
  "result": "pass",
  "limitations": "<none or precise limitations>",
  "artifacts": ["/absolute/path/to/sanitized-screenshot-or-trace"]
}
```

Results are `pass`, `fail`, or `blocked`. A pass requires nonempty artifact files.
Artifacts are copied into the run store; deleting the original does not invalidate
the saved copy. Missing, failed, blocked, stale, or altered required evidence blocks
Quench PASS and downstream approval. Record all UI observations before running
`quench.sh`; a changed observation invalidates prior PASS. Re-run all required
scenarios after a writer retry or commit-hook reverification, even if the final
file content happens to match an older candidate.

This is a tool-independent evidence gate, not an autonomous UI testing service.
The Orchestrator must perform and accurately record the actual tool execution.
Digests prove content consistency; they cannot prove that an observation is true
or that a remote site ran the recorded build.

## Review provenance

Retain the actual dispatch brief and original structured result before recording
the review. The result JSON contains `role`, `runId`, `candidate`, `completion`,
`severity`, `findings`, `evidence`, and `limitations`, matching the receipt fields
exactly. Do not rewrite or silently truncate the verdict. A transport repair may
recover the same result; it must not negotiate a different verdict.

Pass `--provenance <file.json>` to `metadata.sh review`:

```json
{
  "executionId": "<actual agent/thread execution ID>",
  "invocationId": "<agent-record start invocationId>",
  "contextMode": "fresh",
  "input": "/absolute/path/to/sanitized-dispatch-brief",
  "result": "/absolute/path/to/original-structured-result.json"
}
```

Record dispatch/outcome with [agent-model-policy.md](agent-model-policy.md) and include its `invocationId`. The same input/result artifacts must be used. The review gate binds the model record, rejects known profile discrepancies, and retains unknown effective settings explicitly. Existing format-2 provenance without an invocation remains supported without model assurance only when no dispatch records have been introduced; format 3 requires a matching invocation.

Self-review uses the main execution ID and `contextMode: "self"`; independent
review uses a separate execution with `contextMode: "fresh"`. Different required
independent roles must have distinct execution IDs. An absent execution or source
record blocks the new-format gate. Reviewers receive the saved acceptance criteria,
full candidate access, and verification/UI evidence without implementation debate
or earlier reviewer verdicts. Gate tests use synthetic fixtures; these never count
as model or browser execution evidence.

Describe this assurance as **recorded execution/source provenance**, attested by
the Orchestrator. The process controlling local files can fabricate them; this
does not authenticate model identity, enforce permissions, or cryptographically
prove reviewer independence. Custom agent instructions define task-file roles;
all agents inherit the parent permission boundary.
