---
name: pulmu
description: "Run the complete Pulmu software forge for a coding task from inside Codex CLI: prepare a safe branch, inspect the repository, plan, implement, verify, independently review/fix, and commit the result locally, with optional GitHub push and pull request delivery. Use when the user explicitly invokes $pulmu or asks Pulmu to take a coding task through review and delivery. Do not use for read-only questions or explanations."
---

# Pulmu

> **`$pulmu` is the command that starts the whole smithy. Ignite, Inspect, Shape, Hammer, Quench, Hone, and Ship are the forge stages inside it.**

The user should normally invoke exactly one command:

```text
$pulmu "<task>"
```

From that point, run the complete workflow without asking the user to manually invoke each stage. GitHub is optional: every run can finish with a reviewed local commit, while a ready GitHub repository can additionally be pushed and opened as a pull request. Only stop when an external condition makes safe automation impossible (for example: dirty working tree, destructive ambiguity that cannot be resolved from the repository, or repeated verification/review failure).

## Task progress and terminal presentation

Immediately after Pulmu starts, call Codex's `update_plan` tool with exactly the seven top-level forge stages defined in `references/stage-contract.md`. Keep exactly one stage `in_progress` while work is active, keep future stages `pending`, and update the plan whenever the active stage changes. Never add implementation details or `🎨 Pattern` as top-level plan items.

Use the native task list as the primary progress UI. In ordinary progress messages, pair the forge concept with one concrete technical activity:

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

Use `●`, `✓`, `✗`, `↻`, `•`, and `⚠` as the status language; do not repeat their meaning with text such as `active`, `success`, or `retry`. Keep each progress result to one line and replace the active line with a concise completion result when the stage finishes. Do not narrate every file read or internal thought.

When the workflow finishes, print:

```text
🔥 Pulmu complete
   Forge: <Quick|Standard|Full>
   Branch: <branch>
   Verification: <summary>
   Review: <PASS or summary>
   Commit: <sha>
   PR: <url or not created (local delivery)>
```

## Invariants

1. All forge modes go through all seven named stages. A mode changes depth, not stage presence.
2. Only the main Codex session writes application code. Explorer and Reviewer stay read-only.
3. Never force-push.
4. Never merge a PR.
5. Never discard unrelated user changes.
6. A dirty working tree blocks Ignite unless the changes were created by the current Pulmu run.
7. Quench must pass before Ship.
8. High or medium Hone findings must be fixed and re-quenched before Ship, or the run must stop with a clear failure.
9. When a Full Forge creates a PR, it is a draft by default.
10. Do not claim a command/test/review passed unless you actually ran/received it.
11. `🎨 Pattern` is a conditional design pass inside Shape, never an eighth top-level stage.

Read `references/stage-contract.md`, `references/forge-modes.md`, and `references/review-contract.md` before executing the workflow.

## Forge workflow

### 1. 🔥 Ignite — Preparing the forge

Print the Ignite stage line.

Run the skill's `scripts/ignite.sh`, passing the user's task as one argument. The script performs deterministic preflight checks and creates/reuses a `pulmu/*` branch.

Example:

```bash
bash <pulmu-skill-dir>/scripts/ignite.sh "$TASK"
```

Capture its reported base branch and Pulmu branch. If Ignite fails, print `✗` with the concrete reason and stop. Do not work around dirty state by stashing, resetting, cleaning, or deleting user work.

After success, print concise `✓` results (repository/branch/delivery). Treat `PULMU_DELIVERY=local` as a supported result, not a warning or failure.

### 2. 🔎 Inspect — Exploring the repository

Print the Inspect stage line.

Spawn/use the `pulmu_explorer` custom subagent if available. Give it:

- the user's exact task
- base and Pulmu branch names
- a request to identify relevant code paths, conventions, tests, and risk indicators
- for user-facing work, a request to map reusable components, design tokens, layout and interaction conventions, responsive behavior, accessibility patterns, and any Storybook or design system

If the custom agent is unavailable, perform the same inspection yourself without editing files.

Summarize only the evidence needed for Shape. Print a few concise `✓`/`•` lines.

### 3. 📐 Shape — Forming the implementation plan

Print the Shape stage line.

Classify the task as **Quick Forge**, **Standard Forge**, or **Full Forge** using `references/forge-modes.md`.

All modes still use every Pulmu stage.

Create a concrete implementation plan grounded in Inspect evidence. Keep the plan proportional to the mode. Explicitly define:

- intended behavior / acceptance condition
- affected files/components
- test/verification approach
- risks and non-goals

For Full Forge, include migration/rollback/security/compatibility considerations as applicable.

Using Inspect evidence, decide whether the task has meaningful user-facing design impact. UI additions or changes, screens, dashboards, forms, navigation, interactions, responsive or mobile behavior, user-visible states, visual hierarchy, component composition, and other frontend UX changes require `🎨 Pattern`. Backend-only, API-only, infrastructure, CI/CD, test-only, internal refactors, and invisible bug fixes skip it.

When Pattern is required, read `references/design-pass.md` and complete that design pass before Hammer. Pattern determines the intended experience; it does not implement or edit source code. Keep it subordinate to Shape in normal progress messages, for example:

```text
🎨 Pattern — Designing the experience
  ● Defining hierarchy, interaction, responsive behavior, and accessibility
```

Record a concise Pattern brief with the implementation plan so Hammer and Hone can use it. Do not print a Pattern message when the pass is skipped.

Print `✓ Forge: <mode>` and a terse plan summary.

### 4. 🔨 Hammer — Implementing

Print the Hammer stage line.

Implement the plan in the current Pulmu branch. You are the only writer.

Rules:

- prefer existing project patterns and dependencies
- keep scope tight
- add or update meaningful tests when behavior changes
- avoid unrelated refactors
- do not commit yet
- when Pattern ran, implement its recorded hierarchy, states, responsive behavior, accessibility decisions, and design-language reuse

Print brief `•` lines for meaningful file groups, not every edit operation.

### 5. 🌊 Quench — Running verification

Print the Quench stage line.

Run:

```bash
bash <pulmu-skill-dir>/scripts/quench.sh
```

The script discovers common project checks and records its latest log under `.git/`.

If Quench fails:

1. print `↻ Quench retry <n>/3`
2. diagnose the concrete failure
3. return to Hammer only to fix the failure or task-related bug
4. run Quench again

Maximum automatic Quench fix attempts: **3**.

If it still fails, print `✗`, summarize the remaining failure, and stop before Ship.

On success, print `✓` with the checks that passed.

### 6. 🪨 Hone — Reviewing and refining

Print the Hone stage line.

Spawn/use `pulmu_reviewer` if available. Give it:

- original task and acceptance condition
- base branch
- current branch/diff
- Quench evidence
- the Pattern brief when the conditional design pass ran

The Reviewer is read-only and independent from Hammer. When Pattern ran, Hone must also check that the implementation preserves the intended hierarchy, existing design language, responsive behavior, interaction states, accessibility, and visual restraint described in `references/design-pass.md`.

If Hone reports high or medium findings:

1. print `↻ Hone refinement <n>/2`
2. return to Hammer and make the smallest defensible fixes
3. run Quench again
4. run Hone again

Maximum automatic Hone refinement rounds: **2**.

Low-severity, non-blocking suggestions may remain in the final summary. High/medium unresolved findings block Ship.

When review is clear, print `✓ Review: PASS`.

### 7. 📦 Ship — Finalizing delivery

Print the Ship stage line.

Before shipping, inspect `git status` and the final diff. Generate a concise conventional commit title when appropriate.

Choose delivery from the user's request and Ignite output:

- use `local` when the user requests no external writes or Ignite reports local delivery
- use `github` when the user explicitly requests a PR; missing GitHub setup then blocks Ship with a concrete recovery step
- otherwise use Ignite's detected delivery, which preserves PR delivery for ready GitHub repositories and falls back to a local commit elsewhere

For GitHub delivery, also generate a PR body covering purpose, changes, verification, and Pulmu review. Write it to a temporary file outside the repository or under `.git/`.

Run:

```bash
bash <pulmu-skill-dir>/scripts/ship.sh \
  --title "<commit-and-pr-title>" \
  --delivery "<local|github>" \
  [--body-file "<path-to-pr-body>"] \
  [--draft]
```

Use `--draft` for Full Forge GitHub delivery unless the user explicitly requested a ready-for-review PR and the change is demonstrably safe.

The script always creates the local commit. In GitHub delivery it also pushes and creates the PR. It never force-pushes or merges.

Capture the returned commit and optional PR URL, then print the final `🔥 Pulmu complete` block. A successful local delivery completes Pulmu without a PR URL.

## Failure behavior

A Pulmu run is allowed to fail. Never fake success to preserve the metaphor.

Use:

```text
✗ Pulmu stopped
  Stage: <stage>
  Reason: <specific reason>
  Branch: <branch if created>
  Next: <one concrete recovery action>
```

Do not create a PR after failed Quench or blocking Hone findings.
