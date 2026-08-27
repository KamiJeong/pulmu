# Pulmu stage contract

Pulmu is one skill and one public command. The seven stage names form its stable user-facing workflow vocabulary.

## Stage order

1. 🔥 Ignite
2. 🔎 Inspect
3. 📐 Shape
4. 🔨 Hammer
5. 🌊 Quench
6. 🪨 Hone
7. 📦 Ship

Do not reorder these stages in the normal workflow.

## Native task-progress contract

Call Codex's `update_plan` immediately after Pulmu starts. The plan contains exactly these seven stable top-level step strings, in this order:

- `🔥 Ignite — Prepare`
- `🔎 Inspect — Explore`
- `📐 Shape — Design`
- `🔨 Hammer — Implement`
- `🌊 Quench — Verify`
- `🪨 Hone — Review`
- `📦 Ship — Deliver`

Never shorten, expand, or otherwise rewrite these step strings during a run. Do not put lifecycle words such as `active`, `pending`, or `completed` inside them. Keep exactly one item `in_progress` while work is active, all future stages `pending`, and completed stages `completed`; the native `update_plan` status is the only lifecycle indicator. Update the plan immediately before moving to a new stage. Implementation details belong in ordinary progress messages, not additional top-level items.

`🎨 Pattern` is a conditional design pass inside Shape. Never add it as an eighth plan item. When Pattern runs, show it only as a subordinate progress message while Shape remains `in_progress`.

Custom agents are also subordinate work, never plan items. Report them only through concise ordinary progress lines such as `• Explorer mapping relevant modules`, `• Architect defining module boundaries`, or `• 🎨 Pattern — Designer reviewing responsive behavior`. Do not repeat the full plan in normal assistant messages; the native plan UI already owns the checklist.

## Machine-readable synchronization

`update_plan` remains the human progress UI. The current machine-readable state lives in the resolved Git-dir at `pulmu/run.json`; see `run-context.md`. Keep the two transitions adjacent so they do not remain divergent: call `scripts/run-context.sh set-stage <stage> --expect-run-id "$RUN_ID"` as each existing plan item becomes active, then perform the matching `update_plan` change. Do not add Run Context, agents, retries, or Pattern as top-level plan items.

Set the active agent list immediately before spawning a stage's agents and clear it after they finish. Hammer must record `pulmu_smith`. On retries, update both channels through the existing stage sequence and preserve the same run ID:

```text
Quench failure: increment-retry quench → Hammer → Quench
Hone finding:  increment-retry hone → Hammer → Quench → Hone
```

Before advancing normally, mark the current item `completed` and the next item `in_progress` in the same plan update. If Quench fails, return the existing Quench item to `pending`, move the existing Hammer item to `in_progress`, have the same Smith fix the failure, complete Hammer, and move Quench back to `in_progress`. If Hone reports blocking findings, reuse the existing items and same Smith for Hammer → Quench → Hone. Never duplicate retry or reviewer items.

Move Ship to `in_progress` only after Quench passes and Hone has no blocking findings for the exact final diff. Mark Ship `completed` only after the selected delivery finishes: a local commit for local delivery, or commit, push, and a real pull-request URL for GitHub delivery. A successful run finishes with all seven items `completed`.

Expose the workflow identity once per run in ordinary progress output:

```text
🔥 Pulmu — Starting the forge workflow
```

The banner is neither a plan item nor an eighth stage. Show it once at run start, then use the stage presentation below without repeating the banner during transitions or retries.

## Terminal contract

For the currently active stage, show the stage name and one concrete technical activity outside the plan:

```text
🔥 Ignite
  ● Validating repository and delivery access

🔎 Inspect
  ● Mapping relevant code, tests, and conventions

📐 Shape
  ● Defining scope and implementation approach

🔨 Hammer
  ● Implementing code and tests

🌊 Quench
  ● Running lint, typecheck, tests, and build

🪨 Hone
  ● Reviewing and resolving important findings

📦 Ship
  ● Committing and completing the selected delivery
```

Stage details use only the small icon vocabulary:

- `●` current activity
- `✓` completed check/result
- `✗` failure
- `↻` retry/refinement
- `•` subordinate work item
- `⚠` non-blocking warning

Do not add redundant status words such as `active`, `success`, or `retry` after the icons. Replace the progress line with a one-line completion result when a stage finishes. Never reproduce all seven plan steps in ordinary progress output. Avoid turning the terminal into a second dashboard; the native task list is the persistent high-level progress UI.

## Retry paths

```text
Hammer → Quench ──fail──→ Hammer → Quench
Quench → Hone ─finding─→ Hammer → Quench → Hone
```

Ship only follows a passing Quench and non-blocking Hone. Task metadata is finalized once after Shape and reused by review and Ship. It always creates a local commit; GitHub push and pull-request creation are optional delivery steps. Git metadata work remains subordinate Ship progress, never additional top-level tasks.

If a run cannot continue, record the terminal state with `run-context.sh fail` before reporting that Pulmu stopped. For user or session interruption, use `interrupt`. Pass only a stable error code and concise safe explanation—never environment values, tokens, complete command output, logs, or model responses.
