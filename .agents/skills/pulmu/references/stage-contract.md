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

Call Codex's `update_plan` immediately after Pulmu starts. The plan contains exactly these seven top-level items, in this order:

- `🔥 Ignite  — initialize task, validate environment, and understand goal`
- `🔎 Inspect — inspect repository, conventions, tests, and relevant code`
- `📐 Shape   — design the implementation approach and determine scope`
- `🔨 Hammer  — implement the required changes`
- `🌊 Quench  — run tests, lint, typecheck, build, and other validation`
- `🪨 Hone    — review the implementation and fix important findings`
- `📦 Ship    — finalize the selected delivery`

Keep exactly one item `in_progress` while work is active, all future stages `pending`, and completed stages `completed`. Update the plan immediately before moving to a new stage. Implementation details belong in ordinary progress messages, not additional top-level items.

`🎨 Pattern` is a conditional design pass inside Shape. Never add it as an eighth plan item. When Pattern runs, show it only as a subordinate progress message while Shape remains `in_progress`.

Custom agents are also subordinate work, never plan items. Report them only through concise ordinary progress lines such as `• Explorer mapping relevant modules`, `• Architect defining module boundaries`, or `• 🎨 Pattern — Designer reviewing responsive behavior`.

Before advancing normally, mark the current item `completed` and the next item `in_progress` in the same plan update. If Quench fails, return the existing Quench item to `pending`, move the existing Hammer item to `in_progress`, have the same Smith fix the failure, complete Hammer, and move Quench back to `in_progress`. If Hone reports blocking findings, reuse the existing items and same Smith for Hammer → Quench → Hone. Never duplicate retry or reviewer items.

Move Ship to `in_progress` only after Quench passes and Hone has no blocking findings. Mark Ship `completed` only after the selected delivery finishes: a local commit for local delivery, or commit, push, and pull-request creation for GitHub delivery. A successful run finishes with all seven items `completed`.

Expose the workflow identity once per run in ordinary progress output:

```text
🔥 Pulmu — Starting the forge workflow
```

The banner is neither a plan item nor an eighth stage. Show it once at run start, then use the stage presentation below without repeating the banner during transitions or retries.

## Terminal contract

At stage start, show the forge concept and one concrete technical activity:

```text
🔥 Ignite — Preparing the forge
  ● Validating repository and delivery access

🔎 Inspect — Exploring the repository
  ● Mapping relevant code, tests, and conventions

📐 Shape — Forming the plan
  ● Defining scope and implementation approach

🔨 Hammer — Forging the change
  ● Implementing code and tests

🌊 Quench — Verifying the work
  ● Running lint, typecheck, tests, and build

🪨 Hone — Refining the result
  ● Reviewing and resolving important findings

📦 Ship — Preparing delivery
  ● Committing and completing the selected delivery
```

Stage details use only the small icon vocabulary:

- `●` current activity
- `✓` completed check/result
- `✗` failure
- `↻` retry/refinement
- `•` subordinate work item
- `⚠` non-blocking warning

Do not add redundant status words such as `active`, `success`, or `retry` after the icons. Replace the progress line with a one-line completion result when a stage finishes. Avoid turning the terminal into a second dashboard; the native task list is the primary progress UI.

## Retry paths

```text
Hammer → Quench ──fail──→ Hammer → Quench
Quench → Hone ─finding─→ Hammer → Quench → Hone
```

Ship only follows a passing Quench and non-blocking Hone. It always creates a local commit; GitHub push and pull-request creation are optional delivery steps.
