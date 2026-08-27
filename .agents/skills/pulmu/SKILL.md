---
name: pulmu
description: "Run the complete Pulmu software forge for a coding task from inside Codex CLI: orchestrate specialized read-only scouts, architects, designers, and reviewers around one Smith writer; verify the result; and commit locally with optional GitHub pull request delivery. Use when the user explicitly invokes $pulmu or asks Pulmu to take a coding task through review and delivery. Do not use for read-only questions or explanations."
---

# Pulmu

> **`$pulmu` is the command that starts the whole smithy. Ignite, Inspect, Shape, Hammer, Quench, Hone, and Ship are the forge stages inside it.**

The user should normally invoke exactly one command:

```text
$pulmu "<task>"
```

From that point, run the complete workflow without asking the user to manually invoke each stage. GitHub is optional: every run can finish with a reviewed local commit, while a ready GitHub repository can additionally be pushed and opened as a pull request. Only stop when an external condition makes safe automation impossible (for example: dirty working tree, destructive ambiguity that cannot be resolved from the repository, or repeated verification/review failure).

## Task progress and terminal presentation

Immediately after Pulmu starts, call Codex's `update_plan` tool with exactly these seven step strings in this order:

```text
🔥 Ignite — Prepare
🔎 Inspect — Explore
📐 Shape — Design
🔨 Hammer — Implement
🌊 Quench — Verify
🪨 Hone — Review
📦 Ship — Deliver
```

Keep these strings unchanged for the entire run. Keep exactly one stage `in_progress` while work is active, keep future stages `pending`, and update only the native plan status whenever the active stage changes. Do not put status words such as `active`, `pending`, or `completed` inside step text. Never add implementation details or `🎨 Pattern` as top-level plan items.

At the start of every run, expose the workflow identity exactly once in ordinary progress output before substantive Ignite work:

```text
🔥 Pulmu — Starting the forge workflow
```

This banner is not a plan item or forge stage. Do not repeat it on stage transitions or retries.

Use the native task list as the persistent high-level forge checklist. In ordinary progress messages, show only the current stage and one concrete technical activity outside the plan:

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

Use `●`, `✓`, `✗`, `↻`, `•`, and `⚠` as the status language; do not repeat their meaning with text such as `active`, `success`, or `retry`. Keep each progress result to one line and replace the active line with a concise completion result when the stage finishes. Do not repeat the full plan in normal assistant messages, and do not narrate every file read or internal thought.

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
2. The main Codex session is the Orchestrator. It manages the plan, routing, consolidation, retries, and delivery; it does not edit application/source/test files.
3. `pulmu_smith` is the only application/source/test writer. Reuse the same Smith for Quench and Hone fixes. Every other Pulmu agent is read-only.
4. Never force-push.
5. Never merge a PR.
6. Never discard unrelated user changes.
7. A dirty working tree blocks Ignite unless the changes were created by the current Pulmu run.
8. Quench must pass before Ship.
9. High or medium Hone findings must be fixed and re-quenched before Ship, or the run must stop with a clear failure.
10. A high-risk Full Forge creates a draft PR by default when repository policy enables it; Full Forge alone does not force draft status.
11. Do not claim a command/test/review passed unless you actually ran/received it.
12. `🎨 Pattern` is a conditional design pass inside Shape, never an eighth top-level stage.
13. Subagents never become top-level `update_plan` items. Parallelize only independent read-only work, and never spawn agents merely to increase agent count.
14. If `pulmu_smith` is unavailable, stop at Hammer with a recovery step; do not silently fall back to another writer.
15. Finalize task metadata once after Shape. Review and Ship consume it instead of re-inferring it.

Read `references/stage-contract.md`, `references/run-context.md`, `references/forge-modes.md`, `references/agent-orchestration.md`, `references/review-contract.md`, and `references/delivery-policy.md` before executing the workflow.

## Persistent Run Context

Codex `update_plan` is the human progress UI. `<git-dir>/pulmu/run.json` is the machine-readable runtime state. **update_plan shows the forge to humans. Run Context exposes the forge to machines.** Run Context records existing decisions; it never re-infers metadata or changes the seven-stage workflow.

Ignite creates the file and reports `PULMU_RUN_ID`. Capture that ID as `RUN_ID` for the run. Whenever the active plan stage changes, call the deterministic helper immediately adjacent to the `update_plan` transition:

```bash
bash <pulmu-skill-dir>/scripts/run-context.sh set-stage inspect --expect-run-id "$RUN_ID"
```

Before spawning stage agents, set their canonical names; clear them after all finish:

```bash
bash <pulmu-skill-dir>/scripts/run-context.sh set-agents pulmu_explorer pulmu_test_scout --expect-run-id "$RUN_ID"
# spawn/await agents
bash <pulmu-skill-dir>/scripts/run-context.sh set-agents --expect-run-id "$RUN_ID"
```

Use the mode-specific exact agent set. Record `pulmu_smith` throughout Hammer and each Smith fix. Increment `quench` or `hone` before following the existing retry transitions, without creating another run. `metadata.sh finalize` copies canonical Shape metadata, and `ship.sh` records completion only after its existing local/GitHub success gate.

If Pulmu must stop, record a concise safe terminal state first:

```bash
bash <pulmu-skill-dir>/scripts/run-context.sh fail --code "<STABLE_CODE>" --message "<concise reason>" --expect-run-id "$RUN_ID"
```

Use `interrupt` for an interrupted session. Never put credentials, environment values, raw logs, full command output, or model responses in Run Context. A previous `running` state is reported and archived as interrupted only when the next Ignite can actually initialize its replacement; it is never resumed automatically. If dirty work blocks Ignite, report the prior run but leave it unchanged because it may still be live.

## Forge workflow

### 1. 🔥 Ignite

Emit the concise Ignite activity line outside the plan.

Run the skill's `scripts/ignite.sh`, passing the Orchestrator's provisional task type, a short meaningful slug, and the user's task. The script performs deterministic preflight checks, detects the repository base policy, creates/reuses a `pulmu/<mapped-type>/<slug>` branch, and initializes provisional metadata.

Example:

```bash
bash <pulmu-skill-dir>/scripts/ignite.sh \
  --type "<feature|bugfix|refactor|docs|test|chore>" \
  --slug "<short-kebab-slug>" \
  "$TASK"
```

Capture its reported base branch and Pulmu branch. If Ignite fails, print `✗` with the concrete reason and stop. Do not work around dirty state by stashing, resetting, cleaning, or deleting user work.

After success, print concise `✓` results (repository/branch/delivery). Treat `PULMU_DELIVERY=local` as a supported result, not a warning or failure.

Capture `PULMU_RUN_ID` from Ignite. The created state is `running` at `ignite`; all subsequent Run Context mutations in this run use that same ID.

The Orchestrator selects a provisional **Quick**, **Standard**, or **Full** Forge from the task and preflight evidence before Inspect so the correct scouts can be routed. Inspect may reveal evidence that requires escalation to a deeper mode; do not downgrade after mode-specific agents have run.

### 2. 🔎 Inspect

Emit the concise Inspect activity line outside the plan.

Run the mode-specific Inspect agents from `references/agent-orchestration.md`:

- Quick: `pulmu_explorer`
- Standard: `pulmu_explorer` and `pulmu_test_scout`
- Full: `pulmu_explorer`, `pulmu_test_scout`, and `pulmu_risk_scout`

Run independent read-only scouts in parallel when useful. Give them:

- the user's exact task
- base and Pulmu branch names
- their role-specific request from `references/agent-orchestration.md`

Set the Run Context stage to `inspect`, then set the exact active scout names immediately before spawning them. Clear the active list after all scouts finish.

The Orchestrator consolidates all scout evidence into one Inspect summary. It may perform additional read-only inspection itself, but it does not edit task files. If a required role is unavailable, continue only when the missing evidence can be obtained safely without violating the writer contract; otherwise stop with a recovery step.

Summarize only the evidence needed for Shape. Print a few concise `✓`/`•` lines.

### 3. 📐 Shape

Emit the concise Shape activity line outside the plan. Confirm the provisional Forge Mode using Inspect evidence and escalate it when required. All modes still use every Pulmu stage.

For Standard and Full Forge, run read-only `pulmu_architect`. Quick Forge uses the Orchestrator unless complexity warrants the Architect. The Orchestrator consolidates Architect output into the final implementation brief. Explicitly define:

- intended behavior / acceptance condition
- affected files/components
- test/verification approach
- risks and non-goals

For Full Forge, include migration/rollback/security/compatibility considerations as applicable.

Using Inspect evidence, decide whether the task has meaningful user-facing design impact. UI additions or changes, screens, dashboards, forms, navigation, interactions, responsive or mobile behavior, user-visible states, visual hierarchy, component composition, and other frontend UX changes require `🎨 Pattern`. Backend-only, API-only, infrastructure, CI/CD, test-only, internal refactors, and invisible bug fixes skip it.

When Pattern is required, read `references/design-pass.md` and run read-only `pulmu_designer` before Hammer. Pattern determines the intended experience; neither the Designer nor the Orchestrator implements or edits task files. Keep it subordinate to Shape in normal progress messages, for example:

```text
🎨 Pattern — Designing the experience
  ● Defining hierarchy, interaction, responsive behavior, and accessibility
```

The Orchestrator records a concise Pattern brief with the implementation brief so Smith and Hone can use it. Do not print a Pattern message when the pass is skipped.

Finalize the canonical task metadata once, after the architecture and conditional Pattern decisions are complete:

```bash
bash <pulmu-skill-dir>/scripts/metadata.sh finalize \
  --type "<type>" --forge "<quick|standard|full>" --risk "<low|medium|high>" \
  --areas "<comma-separated areas>" --pattern "<true|false>" \
  --security-review "<true|false>" --compatibility-review "<true|false>" \
  --expect-run-id "$RUN_ID"
```

Do not change these fields later or re-infer them in Ship. Pattern automatically propagates frontend and design areas; when Pattern is skipped, do not add design metadata without independent repository evidence.

Print `✓ Forge: <mode>` and a terse plan summary.

Keep Run Context at `shape` while Architect and optional Designer work. Set the active list for each actual agent group and clear it afterward. `metadata.sh finalize` synchronizes the already-decided canonical metadata into Run Context.

### 4. 🔨 Hammer

Emit the concise Hammer activity line outside the plan.

Spawn `pulmu_smith` with the original task, repository instructions, Inspect summary, architecture brief, and Pattern brief when present. Smith is the only task-file writer. Reuse the same Smith agent for all task-related fixes in this run.

Set Run Context to `hammer` and record `pulmu_smith` before spawning or reusing Smith. Clear it only after Smith finishes.

Rules:

- Smith implements the smallest complete source and test change using existing project patterns
- Smith implements the Pattern brief when present
- Smith does not commit, push, create or merge a PR, or force-push
- the Orchestrator does not compete with Smith by editing task files

Print brief `•` lines for meaningful file groups, not every edit operation.

### 5. 🌊 Quench

Emit the concise Quench activity line outside the plan.

Run:

```bash
bash <pulmu-skill-dir>/scripts/quench.sh
```

The script discovers common project checks and records its latest log under `.git/`.

If Quench fails:

1. print `↻ Quench retry <n>/3`
2. increment the Run Context `quench` retry counter
3. diagnose the concrete failure; use read-only `pulmu_failure_analyst` only when root-cause analysis is genuinely needed
4. update Run Context and the existing plan through Hammer, give the diagnosis to the same `pulmu_smith`, then return both to Quench
5. run Quench again

Maximum automatic Quench fix attempts: **3**.

If it still fails, print `✗`, summarize the remaining failure, and stop before Ship.

On success, print `✓` with the checks that passed.

Quench records PASS evidence tied to the exact verified diff. Any later task-file change invalidates downstream evidence and requires Quench again.

### 6. 🪨 Hone

Emit the concise Hone activity line outside the plan.

Run the mode- and risk-specific read-only reviewers from `references/agent-orchestration.md`:

- Quick: `pulmu_reviewer`, plus `pulmu_design_reviewer` when Pattern ran
- Standard: `pulmu_reviewer` and `pulmu_test_reviewer`, plus `pulmu_design_reviewer` when Pattern ran
- Full: the Standard reviewers plus `pulmu_security_reviewer` for security-sensitive changes and `pulmu_compat_reviewer` for compatibility risk; include `pulmu_design_reviewer` when Pattern ran

Independent reviewers may run in parallel. Give each reviewer:

- original task and acceptance condition
- base branch
- current branch/diff
- Quench evidence
- the Pattern brief when the conditional design pass ran

All reviewers are read-only and independent from Smith. The Orchestrator consolidates duplicate or conflicting findings into one severity-ranked Hone result. When Pattern ran, the Design Reviewer checks the implementation against `references/design-pass.md`.

If Hone reports high or medium findings:

1. print `↻ Hone refinement <n>/2`
2. increment the Run Context `hone` retry counter
3. update Run Context and the existing plan through Hammer and give the consolidated findings to the same `pulmu_smith`
4. update both channels to Quench and run it again
5. update both channels to Hone and run review again

Maximum automatic Hone refinement rounds: **2**.

Low-severity, non-blocking suggestions may remain in the final summary. High/medium unresolved findings block Ship.

When review is clear, print `✓ Review: PASS`.

Record the consolidated non-blocking result for the exact Quench diff:

```bash
bash <pulmu-skill-dir>/scripts/metadata.sh hone --result pass --expect-run-id "$RUN_ID"
```

### 7. 📦 Ship

Emit the concise Ship activity line outside the plan.

Set Run Context to `ship` and clear active agents. The deterministic Ship script records `completed` only after the selected delivery succeeds.

Do not spawn a Ship subagent. The Orchestrator uses deterministic Git and GitHub mechanics only.

Before shipping, inspect `git status` and the final diff. Generate a concise Conventional Commit title from the actual diff, not by copying the prompt. Generate delivery metadata with a user-oriented summary, concrete changes, risk context, and focused reviewer guidance:

```bash
bash <pulmu-skill-dir>/scripts/metadata.sh delivery \
  --title "<conventional title>" \
  --summary "<purpose and user result>" \
  --change "<concrete change>" \
  [--change "<concrete change>"] \
  [--risk-reason "<brief reason>"] \
  [--review-focus "<specific focus>"] \
  --expect-run-id "$RUN_ID"
```

This captures the expected changed paths. Do not add unrelated paths afterward.

Choose delivery from the user's request and Ignite output:

- use `local` when the user requests no external writes or Ignite reports local delivery
- use `github` when the user explicitly requests a PR; missing GitHub setup then blocks Ship with a concrete recovery step
- otherwise use Ignite's detected delivery, which preserves PR delivery for ready GitHub repositories and falls back to a local commit elsewhere

For GitHub delivery, the deterministic Ship script renders the canonical PR body from task metadata, delivery metadata, and actual Quench evidence. It discovers existing repository labels before PR creation, applies only available labels by default, and reports missing labels. It never assigns arbitrary reviewers or assignees; CODEOWNERS and configured repository automation remain authoritative.

The legacy `--body-file` option remains accepted as supplemental context. Ship appends it after the canonical Summary, Changes, Pulmu Forge, Verification, Risk, Review Focus, and Pulmu Metadata sections; it never lets caller content replace evidence-grounded sections. Existing PR lookup uses both head and base, and a matching PR is updated to the canonical title and body before labels are reconciled. Label discovery, creation, and application failures are non-blocking: report skipped or unapplied labels and continue to emit a valid PR URL.

Run:

```bash
bash <pulmu-skill-dir>/scripts/ship.sh \
  --delivery "<local|github>" \
  --expect-run-id "$RUN_ID" \
  [--draft]
```

High-risk Full Forge delivery becomes draft by configured default. Use explicit `--draft` for another evidence-based case; do not make every Full Forge PR draft.

The script verifies the final-diff evidence, stages only the recorded path manifest, creates one cohesive commit, and normally pushes. It creates or reuses an open PR, applies the bounded label set, and requires a real PR URL. It never force-pushes, auto-merges, or merges.

During Ship, use ordinary subordinate progress messages without adding top-level tasks:

```text
📦 Ship
  ● Generating commit and PR metadata
  ● Pushing pulmu/feat/user-search
  ● Applying available GitHub labels
```

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

Before printing this stopped block, use Run Context `fail` with the current stage, a stable concise code, and a sanitized explanation. Use `interrupt` instead when the session or user stops a non-failed run.
