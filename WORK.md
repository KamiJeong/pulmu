# Pulmu work state

## Product sentence

Pulmu turns one Codex CLI task prompt into a reviewed local commit, with optional GitHub pull request delivery.

## Core metaphor

`$pulmu` is the command that starts the entire smithy.
Ignite / Inspect / Shape / Hammer / Quench / Hone / Ship are the forge stages inside it.

## v0.1.0 vertical slice

- `$pulmu <task>` skill entrypoint
- visible emoji stage presentation in Codex CLI output
- Quick / Standard / Full Forge classification
- deterministic Ignite preflight + branch creation
- read-only Explorer subagent
- main Codex planning and implementation
- deterministic Quench verification
- fix/retry loop
- read-only Reviewer subagent
- review/fix/reverify loop
- deterministic Ship commit with optional GitHub push/PR
- Full Forge draft PR when using GitHub delivery
- zero-install demo repository generator

## Next likely work

1. Run real Codex CLI E2E and tighten instructions where the model skips/duplicates a stage.
2. Persist structured stage events for Agent Observatory.
3. Add repository-specific verification policy overrides (`.pulmu.toml`).
4. Add worktree-per-run mode.
5. Package Pulmu as a distributable Codex/ChatGPT plugin once the skill contract is stable.
