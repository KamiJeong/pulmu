# Pulmu work state

## Product sentence

Pulmu turns one Codex CLI task prompt into a reviewed local commit, with optional GitHub pull request delivery.

## Core metaphor

`$pulmu` is the command that starts the entire smithy.
Ignite / Inspect / Shape / Hammer / Quench / Hone / Ship are the forge stages inside it.

## Multi-agent orchestration

```text
Orchestrator
  ↓
Scouts
  ↓
Architect / Designer
  ↓
Smith
  ↓
Quench
  ↓
Independent Reviewers
  ↓
Ship
```

Orchestrator decides. Scouts investigate. Architect and Designer shape. Smith forges. Quench verifies. Reviewers inspect. Ship delivers.

- The main Codex session orchestrates the seven stages and never competes with Smith for task-file writes.
- `pulmu_smith` is the only application/source/test writer and remains responsible for retry fixes.
- Scouts, Architect, Designer, Failure Analyst, and Reviewers are read-only.
- Independent read-only work may run in parallel; writer work never does.
- Pattern remains conditional and nested inside Shape.
- Ignite, deterministic Quench verification, and Ship use no subagent.

## Next likely work

1. Run real Codex CLI E2E and tighten instructions where the model skips/duplicates a stage.
2. Persist structured stage events for Agent Observatory.
3. Add repository-specific verification policy overrides (`.pulmu.toml`).
4. Add worktree-per-run mode.
5. Package Pulmu as a distributable Codex/ChatGPT plugin once the skill contract is stable.
