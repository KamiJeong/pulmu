# Pulmu Run Context

Pulmu exposes the same forge through two complementary state channels:

> **update_plan shows the forge to humans. Run Context exposes the forge to machines.**

```text
$pulmu
   │
   ├── update_plan
   │     └─ Human progress UI
   │
   └── Pulmu Run Context
         └─ Machine-readable workflow state
                 │
                 ├─ Codex
                 ├─ future resume
                 └─ Observatory
```

Run Context is an observability record, not a second inference engine. Shape's finalized canonical metadata is copied into it unchanged. It does not replace `update_plan`, add a stage, or alter multi-agent routing, Pattern, verification, review, or delivery policy.

## Location and durability

The current state is stored at the resolved Git metadata path:

```text
<git-dir>/pulmu/run.json
<git-dir>/pulmu/runs/<runId>.json
```

For an ordinary checkout this appears as `.git/pulmu/run.json`. Linked worktrees use their own resolved Git-dir, so state does not leak between worktrees. Git metadata is outside the working-tree index and is never committed. Terminal and interrupted runs receive an immutable best-effort history snapshot.

`scripts/run-context.py` is the standard-library state engine. `scripts/run-context.sh` is its stable Bash entrypoint. Every mutation holds an exclusive lock, validates the complete schema, and uses an atomic same-directory replace with owner-only permissions. Reads reject malformed state and symlinks. `init` may quarantine a malformed current file under `runs/corrupt-*.json`; ordinary mutations fail closed.

## Schema version 1

```json
{
  "schemaVersion": 1,
  "workflow": "pulmu",
  "pulmuVersion": "0.2.0",
  "runId": "20260827T091500Z-a1b2c3d4e5f6",
  "status": "running",
  "task": { "prompt": "Add responsive user search", "type": "feature" },
  "forge": "standard",
  "risk": "medium",
  "areas": ["frontend", "design"],
  "pattern": true,
  "stage": { "current": "hammer", "status": "in_progress" },
  "git": {
    "baseBranch": "main",
    "branch": "pulmu/feat/user-search",
    "commit": null
  },
  "agents": { "active": ["pulmu_smith"] },
  "retries": { "quench": 0, "hone": 0 },
  "startedAt": "2026-08-27T09:15:00Z",
  "updatedAt": "2026-08-27T09:18:00Z",
  "completedAt": null,
  "interruptedAt": null,
  "pr": null,
  "error": null
}
```

Before Shape finalizes metadata, `forge` and `risk` are `null`, `areas` is empty, and `pattern` is `false`. `sync-metadata` copies the finalized type, forge, risk, areas, Pattern flag, and branch provenance; it never re-infers them.

The only top-level stages are `ignite`, `inspect`, `shape`, `hammer`, `quench`, `hone`, and `ship`. Pattern remains nested inside Shape. Run status is `running`, `completed`, `failed`, or `interrupted`.

## Lifecycle and synchronization

Ignite initializes one run ID. Every later operation mutates that same run. The Orchestrator keeps Run Context changes adjacent to the matching `update_plan` transition:

```bash
bash <skill>/scripts/run-context.sh set-stage inspect --expect-run-id "$RUN_ID"
bash <skill>/scripts/run-context.sh set-agents pulmu_explorer pulmu_test_scout --expect-run-id "$RUN_ID"
# spawn and await the scouts
bash <skill>/scripts/run-context.sh set-agents --expect-run-id "$RUN_ID"
```

The expected-run-ID guard prevents a delayed agent or command from mutating a newer run. Metadata and Ship operations require the ID returned by Ignite, and every Run Context mutation they perform passes it through. Agent names are recorded before agents start and cleared after they finish. At minimum, Hammer records `pulmu_smith`; read-only parallel groups should also be recorded when practical.

Retry paths reuse the same run ID and explicitly record both the retry count and every stage transition:

```text
Quench failure: quench → increment quench → hammer → quench
Hone finding:  hone → increment hone → hammer → quench → hone
```

Run Context completion does not weaken Ship. Local delivery completes only after the reviewed local commit exists. GitHub delivery completes only after Ship obtains a validated pull-request URL and matching PR number. A terminal run records Ship as completed, clears active agents, records the commit and optional PR, sets `completedAt`, and writes a history snapshot.

When automation cannot continue, the Orchestrator calls `fail` with a short stable code and concise message; its terminal update is recorded in `updatedAt`. An external cancellation uses `interrupt` and records `interruptedAt`; successful delivery records `completedAt`. The terminal fields cannot contradict the lifecycle status. Neither operation stores command logs or model output. Prompt and error fields are length-bounded and redact common credential shapes; callers must never pass tokens, environment dumps, raw command output, or model responses.

## Previous runs

Ignite detects current state before initialization. If preflight permits a replacement run to initialize, a valid previous `running` state is reported, marked `interrupted`, archived, and replaced with a distinct run ID; Pulmu never resumes it automatically. If a dirty working tree blocks Ignite first, Pulmu reports the previous run ID, stage, and branch but leaves it `running`, because dirtiness alone cannot distinguish a live Smith from a stale process. A malformed regular file is quarantined and replaced only by explicit `init`; other operations fail closed.

Legacy metadata without a `run_id` reuses only a compatible `running` context whose task type, sanitized prompt, base, and branch match verified provenance. A terminal context is preserved in history and replaced by a distinct new running context before legacy metadata synchronization.

## Helper operations

```text
detect
init
set-stage <stage>
set-agents [agent...]
sync-metadata <canonical metadata>
increment-retry <quench|hone>
complete --delivery <local|github> --commit <sha> [PR fields]
fail --code <CODE> --message <concise message>
interrupt [--message <concise message>]
show [--format json|text]
```

For a human-readable debug view, run:

```bash
bash <skill>/scripts/pulmu-status.sh
```

External observability tools should read `run.json` as the contract. It exposes workflow identity, run ID, lifecycle status, sanitized task metadata, Forge mode, risk, areas, Pattern use, current stage, active agents, retry counts, Git branch/commit, timestamps, concise failure information, and the validated PR URL when one exists.
