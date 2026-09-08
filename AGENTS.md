# Pulmu repository instructions

Pulmu is a Codex CLI workflow skill.

## Product model

`$pulmu` is the single public command that starts the whole smithy.
Ignite, Inspect, Shape, Hammer, Quench, Hone, and Ship are internal forge stages.
Do not turn the seven stages into seven required user commands.

## Design rules

- Keep the default UX: `codex` → `$pulmu "<task>"` → necessity assessment, then a verified local commit for development work, plus a PR URL when GitHub delivery is ready.
- Keep stage presentation visible and stable.
- Expose `🔥 Pulmu — Starting the forge workflow` once at run start as workflow identity; it is not a plan item or stage.
- The main Codex session is the Orchestrator: it owns stage transitions, routing, consolidation, retries, and delivery.
- Preserve one-writer semantics. A run designates the main Orchestrator or `pulmu_smith`; every other Pulmu agent remains read-only.
- Keep independent read-only agent work parallel where useful, but never spawn agents merely to increase agent count.
- Keep GitHub delivery optional. Local-only development runs finish with a commit whose verification and review assurance are explicit.
- Do not force push, auto-merge, or erase unrelated working-tree changes.
- Prefer deterministic shell scripts for Git, verification, and PR mechanics.
- Prefer direct Orchestrator reasoning for small work; use subagents only when independent evidence is worth their cost.
- All forge modes pass through all seven stages; modes change depth, not the stage vocabulary.
- Keep `🎨 Pattern` conditional and nested inside Shape for work with meaningful user-facing design impact; never promote it to an eighth top-level stage.
- Finish advisory/no-change requests before Ignite without fake stages, branches, state, or commits.
- Require independent review for medium/high risk and specialist review for explicit security/compatibility risk regardless of Forge depth.

## Validation

Run `./tests/test.sh` after changing Pulmu scripts.
