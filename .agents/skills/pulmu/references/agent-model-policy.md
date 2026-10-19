# Agent model selection and execution records

Read when dispatching an agent. Role defaults are starting points, not measured
quality or savings claims. The Orchestrator keeps the user's selected model.

## Select a profile before dispatch

Use the canonical role's default TOML for bounded work. Two optional profiles
preserve the same responsibilities and increase only reasoning effort:

| Canonical role | Default | High profile | Use high when |
| --- | --- | --- | --- |
| `pulmu_smith` | Sol 6.1 / medium | `pulmu_smith_high`: Sol 6.1 / high | implementation requires reasoning about races, transaction/rollback invariants, or interacting state machines; or a diagnosed reasoning gap remains after a substantive correction |
| `pulmu_test_reviewer` | Sol 6.1 / medium | `pulmu_test_reviewer_high`: Sol 6.1 / high | checking failure recovery, concurrency interleavings, migration safety, or whether tests can distinguish a subtly incorrect implementation |

These are hypotheses to evaluate, not empirically superior profiles. High is
optional even on a large diff. File count, a generic test failure, a timeout, or
an unavailable tool alone does not justify escalation. First obtain missing
evidence. Retain other role defaults; do not introduce automatic Astra, xhigh,
max, or multi-model review. A default profile may remain sufficient for a risky
task if the scoped question is bounded and the required assurance is preserved.

Luna scouts collect paths, facts, and unresolved questions. The Orchestrator
confirms test sufficiency and cross-cutting conclusions, or gives the precise
unknown to an Architect/Risk Scout; do not repeat their entire scan. Reviewer
checks behavioral correctness; Test Reviewer challenges the test oracle with
concrete incorrect implementations the tests might accept. Separate their
questions rather than assuming different role names create different judgment.

Inspect the actual installed profile:

```bash
bash <skill>/scripts/run-context.sh agent-profile --role pulmu_smith --profile high
```

This returns the requested model/effort, custom agent type, and TOML path. The Python 3.10-compatible reader accepts the bundled quoted scalar header format before `developer_instructions`; it rejects unsupported formatting rather than guessing. It does
not establish model availability or runtime identity. Confirm the type/model is
exposed by the active runtime. Prefer the named custom agent. If a newly installed
profile is unavailable, use a fresh `default` agent only when the runtime supports
explicit model AND effort and the entire profile's developer instructions can be
passed with the brief. Record `agentType: "default"` and the fallback reason.
Otherwise stop that dispatch and report the unsupported profile; do not silently
inherit or downgrade. Do not edit global settings or restart the user's session.

Canonical routing stays unchanged: metadata writer and active role are
`pulmu_smith`, including for `pulmu_smith_high`; a high test reviewer returns
`role: "pulmu_test_reviewer"`. There is still one writer. Before switching Smith
profiles, stop the old writer and confirm it has stopped. Start a new execution
with saved intent and current files; never activate two Smiths. Preserve retry
budgets. Each independent reviewer starts fresh with `fork_turns="none"` or its
equivalent, including after escalation, and does not receive previous verdicts.
The sole same-thread exception is one transport/format repair: close the malformed
invocation as failed/interrupted, open the existing second review attempt, and
resume the same role/profile on the same candidate. Record the new invocation
with its actual repair brief; the helper links `repairOf` to the original. Preserve
the substantive verdict. No third invocation or reuse across roles/candidates is
allowed. A completed verdict is not reopened for persuasion.

## Show every invocation

Before each spawn or resumed assignment, show one ordinary progress line with
role, requested model/effort, purpose, and why independent work is useful. Group
parallel dispatches in one message with a separate line per role. For example:

```text
• Test Reviewer — gpt-6.1-sol / high (requested): inspect whether recovery tests catch partial writes; separate review of failure behavior.
```

On completion/failure show outcome and model observation status (`runtime-reported`,
`unverified`, or `mismatch`). Do not present TOML values, spawn arguments, the
agent's own identity claims, or a role's name as runtime-confirmed model identity.
No extra top-level stages and no additional approval question are needed.

## Retain dispatch and outcome

Keep sanitized briefs/results and runtime metadata in local evidence only. Open `metadata.sh review-attempt` before reviewer dispatch. After
spawn returns its actual thread/execution ID, record `agent-record start`. For a
resumed Smith assignment use the same execution ID but a new invocation record.
Self-review uses `pulmu_self_review`, default profile, and `agentType:
"orchestrator"`; its requested model/effort remain null (inherited).

Start file:

```json
{
  "executionId": "<runtime thread ID>",
  "role": "pulmu_test_reviewer",
  "profile": "high",
  "agentType": "pulmu_test_reviewer_high",
  "reason": "Independent check of partial-write recovery tests",
  "brief": "/absolute/path/to/actual-dispatch-brief.txt"
}
```

```bash
bash <skill>/scripts/run-context.sh agent-record start --file start.json --expect-run-id "$RUN_ID"
```

Save the returned `invocationId`. It differs from `executionId` so a reused thread
does not overwrite earlier work. Start records bind the run, stage, requested
profile/configuration, brief, and current Quench candidate for review work.

Finish file when runtime identity is unavailable:

```json
{
  "invocationId": "<returned call ID>",
  "status": "completed",
  "summary": "PASS; recovery assertions inspected",
  "result": "/absolute/path/to/original-result.json",
  "observed": {
    "model": null,
    "effort": null,
    "source": null,
    "limitations": "Runtime did not expose effective model or effort"
  }
}
```

```bash
bash <skill>/scripts/run-context.sh agent-record finish --file finish.json --expect-run-id "$RUN_ID"
```

Use `failed` or `interrupted` for those outcomes; their `result` may be null.
`completed` requires the retained original result. Final invocation records are
immutable through the helper. An interrupted run permits closing outstanding
invocations, but no new starts. Run `evidence-summary` to inspect recorded model
assurance. Recorded `running` status is not a liveness probe.

When the runtime exposes either effective value, put it in `observed` and retain
a runtime source JSON with matching `executionId`, `model`, and `effort` (null
for an unavailable field). Preserve the raw runtime export within that JSON;
if normalization is needed, document it in `limitations`. Do not fabricate a
source from the desired configuration. Partial information stays `unverified`.
A known discrepancy is `mismatch`; the helper records it honestly. A mismatched
review cannot satisfy Hone/Ship. Stop and resolve mismatched writer/scout routing
before relying on its work. Runtime reports remain Orchestrator-attested, not
cryptographic proof of identity.

In reviewer provenance include the returned `invocationId` as well as execution
ID and the exact same brief/result paths. The gate binds the invocation snapshot
to the review and rechecks artifacts. Existing metadata-format-2 records without any dispatch records remain supported
with model identity explicitly unverified; they do not acquire model assurance
retroactively. New format-3 runs require a matching completed invocation for every
review, including self-review. Introducing dispatch records into an older run also
requires linking its reviews. New workflow dispatches must use these records.
Unavailable identity alone does not block a correctly routed review; missing,
failed, stale, or inconsistent invocation evidence does.

## Evaluate before promoting a default

Use `efficiency-evaluation.md`. Prioritize paired Smith medium/high and Test
Reviewer medium/high comparisons, varying one role at a time. Include routine
implementation, concurrency, authorization, migration, and UI cases. Record
requested and observed profiles plus unknowns; runtime-unverified runs cannot
establish a comparison of effective model settings. Count all retries, failed
runs, escaped defects, reviewer false positives, human corrections, total wall
time, and complete main/child usage. Invocation timestamps are bookkeeping and
exclude spawn setup; they are not full-workflow latency measurements. Missing
usage remains unknown. No fabricated benchmark numbers or inferred savings.
