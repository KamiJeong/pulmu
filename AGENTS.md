# Pulmu repository instructions

Pulmu is a Codex CLI workflow skill.

## Product model

`$pulmu` is the single public command that starts the whole smithy.
Ignite, Inspect, Shape, Hammer, Quench, Hone, and Ship are internal forge stages.
Do not turn the seven stages into seven required user commands.

## Design rules

- Keep the default UX: `codex` → `$pulmu "<task>"` → PR URL.
- Keep stage presentation visible and stable.
- Preserve one-writer semantics. Explorer and Reviewer remain read-only.
- Do not force push, auto-merge, or erase unrelated working-tree changes.
- Prefer deterministic shell scripts for Git, verification, and PR mechanics.
- Prefer Codex reasoning/subagents for repository understanding, implementation, and review.
- All forge modes pass through all seven stages; modes change depth, not the stage vocabulary.

## Validation

Run `./tests/test.sh` after changing Pulmu scripts.
