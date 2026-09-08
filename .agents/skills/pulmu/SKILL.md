---
name: pulmu
description: "Take a coding task through an adaptive Codex forge: first assess whether a change is needed, then use one writer, proportional investigation and review, deterministic verification, a local commit, and optional GitHub delivery. Use when the user explicitly invokes $pulmu or asks Pulmu to implement and deliver a repository change. Do not use for a read-only answer unless the user explicitly asks Pulmu to assess the task."
---

# Pulmu

`$pulmu "<task>"` is the single public command. Ignite, Inspect, Shape, Hammer, Quench, Hone, and Ship remain internal stages for an actual development run.

## Before starting the forge

Perform a brief read-only necessity assessment before creating a branch, Run Context, plan, or stage output. Check the repository just far enough to decide whether:

- the requested problem exists and needs a code or documentation change;
- existing behavior, configuration, or documented usage already solves it;
- a materially smaller change would meet the goal;
- a consequential product, architecture, or design choice remains open.

If no repository change is useful, explain the evidence and finish as an advisory/no-change result. Do not show the Pulmu banner, fake seven stages, create a branch or state file, or create an empty commit. A read-only explanation requested from the outset also finishes directly.

When one option is clearly best and the consequence is small, state the judgment briefly and continue. When alternatives materially change user-visible behavior, compatibility, cost, or scope, recommend one option, explain the practical tradeoffs, and wait for the user's choice. Honor choices already made in the conversation; do not ask again. If the user delegated the choice, choose and proceed.

For a consequential UI request with no product-level visual and experience direction, read [design-selection.md](references/design-selection.md) during this assessment. Produce the recommended and alternative viewable preview as disposable, non-repository artifacts before asking the user to choose; do not modify task files or create the work branch for the preview. Once chosen, Pattern records the implementable direction inside Shape. If the user delegated the choice, select the recommendation and begin the forge.

## Core invariants

For an actual development run:

1. Expose `🔥 Pulmu — Starting the forge workflow` exactly once, then create the native seven-step plan with Codex's `update_plan` tool from [stage-contract.md](references/stage-contract.md).
2. Keep the seven stage names and order stable. Pattern remains conditional inside Shape.
3. Designate exactly one task-file writer for the run: the main Orchestrator or `pulmu_smith`. Never run them as competing writers.
4. Use subagents only when their independent evidence is worth their context and handoff cost. Tiny low-risk work may use zero subagents.
5. Quench must execute the finalized verification plan and bind PASS evidence to the exact candidate.
6. Hone must record the declared assurance honestly. A self-review receipt is distinct from an independent reviewer receipt and cannot satisfy an independent-review route.
7. Medium/high risk requires fresh independent review. Explicit security or compatibility risk requires its specialist reviewer regardless of Forge depth.
8. Do not claim an unperformed check or review. High/medium findings must be fixed, re-quenched, and re-reviewed, or the run stops.
9. Ship rejects pre-staged content and candidate drift. Never force-push, auto-merge, merge a PR, or discard unrelated changes.
10. Finalize task and execution metadata once after Shape. Later scripts consume it instead of re-inferring it.

Read [stage-contract.md](references/stage-contract.md) and [run-context.md](references/run-context.md) when beginning an actual development run. Read [delivery-policy.md](references/delivery-policy.md) before Ship.

## Adaptive execution

Forge depth and execution path are separate decisions. Select Quick, Standard, or Full using [forge-modes.md](references/forge-modes.md). Then choose the least costly execution path that can produce the evidence the task needs:

| Path | Writer | Review | Use when |
| --- | --- | --- | --- |
| `direct` | Orchestrator | explicit self-review | low-risk, bounded work where fresh independent context is unlikely to change the result |
| `reviewed` | Orchestrator | fresh independent review | implementation benefits from one continuous strong context but failure cost warrants separation |
| `delegated` | Orchestrator or `pulmu_smith` | fresh independent review | independent investigation or a separate writer materially helps with a broad, unfamiliar, or risky change |

The configured model and effort values in `.codex/agents` are defaults for roles that are actually spawned. Do not replace those role defaults merely because the main session uses another model. Read [agent-orchestration.md](references/agent-orchestration.md) only when delegating investigation, Pattern work, implementation, failure analysis, or independent review.

After Shape, finalize both task and routing metadata:

```bash
bash <pulmu-skill-dir>/scripts/metadata.sh finalize \
  --type "<feature|bugfix|refactor|docs|test|chore>" \
  --forge "<quick|standard|full>" --risk "<low|medium|high>" \
  --areas "<one-to-three-comma-separated-areas>" --pattern "<true|false>" \
  --execution "<direct|reviewed|delegated>" \
  --writer "<orchestrator|pulmu_smith>" \
  --review-mode "<self|independent>" --test-review "<true|false>" \
  --security-review "<true|false>" --compatibility-review "<true|false>" \
  --expect-run-id "$RUN_ID"
```

`direct` is valid only for low-risk Orchestrator-written work with self-review and no specialist/test reviewer. `reviewed` uses the Orchestrator and independent review. `delegated` uses independent review and records whichever single writer was selected. The runtime rejects inconsistent combinations.

Record at least one repository-relative, noninteractive verification command with `metadata.sh verification` before Hammer. Documentation work still needs a relevant check such as `git diff --check`.

## Stage routing

- **Ignite:** after the necessity decision, choose the work-branch name from the user's explicit name first, then explicit repository naming instructions, then the default `<type>/<slug>` (optionally namespaced by `git.branch_prefix`). Do not infer a team convention from a few existing branches. Pass a user/repository-specific full name using `scripts/ignite.sh --branch "<name>"`; include issue IDs only when supplied or required by an explicit repository rule. Capture `PULMU_RUN_ID` and the actual branch reported after collision handling, and keep every later mutation bound to the run ID.
- **Inspect:** the Orchestrator may inspect directly. Spawn focused scouts only for independent questions that can usefully run in parallel.
- **Shape:** state acceptance behavior, affected boundaries, verification, risks, non-goals, Forge depth, execution path, writer, and review routing. Use an Architect only when the design work justifies a separate context.
- **Pattern:** required for meaningful user-facing UI/UX changes, but the Orchestrator may own it. A Designer is optional. Follow [design-pass.md](references/design-pass.md); when the project lacks a coherent UI direction, also read [design-selection.md](references/design-selection.md).
- **Hammer:** the designated writer implements. Record `pulmu_smith` as active only when Smith is the writer. The main session writes directly only when metadata names `orchestrator`.
- **Quench:** run `scripts/quench.sh`. Use the bounded retry behavior in [stage-contract.md]. A Failure Analyst is conditional.
- **Hone:** follow [review-contract.md](references/review-contract.md). Direct work records `pulmu_self_review`; reviewed/delegated work starts required agents in fresh contexts. Security and compatibility flags always route specialists.
- **Ship:** generate delivery metadata from the actual diff, then run `scripts/ship.sh` for local or GitHub delivery.

If implementation reveals a consequential requirement outside finalized Shape, preserve the task files and return the same run to Shape explicitly:

```bash
bash <pulmu-skill-dir>/scripts/run-context.sh replan \
  --reason "<concise new scope or risk evidence>" --expect-run-id "$RUN_ID"
```

This keeps the run ID, branch, work, and consumed retry counts, clears active agents, and invalidates finalized routing, verification, review, and delivery evidence. Present any newly consequential choice, then finalize Shape and verification again before returning to Hammer. Do not silently mutate routing or pretend the original review plan covers the new scope.

## Completion

For a successful development run, report Forge depth, execution path, designated writer, verification, review assurance (`self` or `independent`), commit, and optional PR URL. Say “reviewed commit” only when review metadata shows what kind of review occurred; do not present self-review as independent review.

If a stage cannot safely continue, record a concise failure with `run-context.sh fail` and report the stage, reason, preserved branch, and one recovery action. A failed Quench or blocking Hone result never proceeds to Ship.
