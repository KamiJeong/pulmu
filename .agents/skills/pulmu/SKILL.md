---
name: pulmu
description: Run the complete Pulmu software forge for a coding task from inside Codex CLI: prepare a safe branch, inspect the repository, plan, implement, verify, independently review/fix, commit, push, and open a GitHub pull request. Use when the user explicitly invokes $pulmu or asks Pulmu to take a task all the way to a PR. Do not use for read-only questions, explanations, or when the user does not want code/GitHub changes.
---

# Pulmu

> **`$pulmu` is the command that starts the whole smithy. Ignite, Inspect, Shape, Hammer, Quench, Hone, and Ship are the forge stages inside it.**

The user should normally invoke exactly one command:

```text
$pulmu "<task>"
```

From that point, run the complete workflow without asking the user to manually invoke each stage. Only stop when an external condition makes safe automation impossible (for example: dirty working tree, missing GitHub authentication, destructive ambiguity that cannot be resolved from the repository, or repeated verification/review failure).

## Mandatory terminal presentation

Make forge progress visible in the Codex CLI conversation. At the start of each stage, emit its line exactly once, before doing that stage's substantive work:

```text
🔥 Ignite   Preparing the forge...
🔎 Inspect  Exploring the repository...
📐 Shape    Forming the implementation plan...
🔨 Hammer   Implementing...
🌊 Quench   Running verification...
🪨 Hone     Reviewing and refining...
📦 Ship     Creating the pull request...
```

Use these status markers beneath a stage:

```text
● active
✓ success
✗ failed
↻ retry
• sub-task
⚠ warning
```

Keep stage updates concise. Do not narrate every file read or every internal thought. Codex's native tool output can remain native; Pulmu's stage lines are an additional workflow layer.

When the workflow finishes, print:

```text
🔥 Pulmu complete
   Forge: <Quick|Standard|Full>
   Branch: <branch>
   Verification: <summary>
   Review: <PASS or summary>
   PR: <url>
```

## Invariants

1. All forge modes go through all seven named stages. A mode changes depth, not stage presence.
2. Only the main Codex session writes application code. Explorer and Reviewer stay read-only.
3. Never force-push.
4. Never merge the PR.
5. Never discard unrelated user changes.
6. A dirty working tree blocks Ignite unless the changes were created by the current Pulmu run.
7. Quench must pass before Ship.
8. High or medium Hone findings must be fixed and re-quenched before Ship, or the run must stop with a clear failure.
9. Full Forge ships as a draft PR by default.
10. Do not claim a command/test/review passed unless you actually ran/received it.

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

After success, print concise `✓` results (repository/GitHub/branch).

### 2. 🔎 Inspect — Exploring the repository

Print the Inspect stage line.

Spawn/use the `pulmu_explorer` custom subagent if available. Give it:

- the user's exact task
- base and Pulmu branch names
- a request to identify relevant code paths, conventions, tests, and risk indicators

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

The Reviewer is read-only and independent from Hammer.

If Hone reports high or medium findings:

1. print `↻ Hone refinement <n>/2`
2. return to Hammer and make the smallest defensible fixes
3. run Quench again
4. run Hone again

Maximum automatic Hone refinement rounds: **2**.

Low-severity, non-blocking suggestions may remain in the final summary. High/medium unresolved findings block Ship.

When review is clear, print `✓ Review: PASS`.

### 7. 📦 Ship — Creating the pull request

Print the Ship stage line.

Before shipping, inspect `git status` and the final diff. Generate:

- a concise conventional commit title when appropriate
- a PR body covering purpose, changes, verification, and Pulmu review

Write the PR body to a temporary file outside the repository or under `.git/`.

Run:

```bash
bash <pulmu-skill-dir>/scripts/ship.sh \
  --title "<commit-and-pr-title>" \
  --body-file "<path-to-pr-body>" \
  [--draft]
```

Use `--draft` for Full Forge unless the user explicitly requested a ready-for-review PR and the change is demonstrably safe.

The script commits, pushes, and creates the PR. It never merges.

Capture the returned PR URL and print the final `🔥 Pulmu complete` block.

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
