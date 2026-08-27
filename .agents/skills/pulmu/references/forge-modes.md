# Forge modes

Forge mode controls depth and agent routing, not stage presence. Select a provisional mode during Ignite so Inspect can use the correct scouts. Inspect evidence may escalate the mode before Shape completes; do not downgrade after mode-specific agents have run.

`🎨 Pattern` is independent of forge mode. Run it inside Shape whenever Inspect finds meaningful user-facing design impact, even in Quick Forge, and keep its depth proportional to the task. Skip it in any mode when the change has no meaningful user-facing design effect. Read `design-pass.md` only when Pattern runs.

Read `agent-orchestration.md` for the authoritative mode-by-stage agent matrix and model/effort policy.

## Quick Forge

Use for narrowly scoped, low-risk work such as:

- one/few-file bug fixes
- small UI behavior
- straightforward tests
- local refactors with no public contract change

Inspect uses Explorer, Shape stays with the Orchestrator unless Architect is warranted, Hammer uses Smith, and Hone uses Reviewer plus Design Reviewer when Pattern ran. Designer still runs when Pattern is required. All seven stages still run.

## Standard Forge

Default for normal features and non-trivial fixes:

- multiple related files
- new application behavior
- API integration without breaking contracts
- meaningful state/data-flow changes

Inspect uses Explorer and Test Scout. Shape uses Architect and conditional Designer. Hammer uses Smith. Hone uses Reviewer and Test Reviewer, plus Design Reviewer when Pattern ran.

## Full Forge

Use when any of these are present:

- database/schema migration
- authentication/authorization/security-sensitive behavior
- breaking API/public contract changes
- cross-cutting architecture changes
- infrastructure/deployment changes
- large dependency/framework migration
- high blast radius or uncertain rollback

Inspect adds Risk Scout. Shape uses Architect and conditional Designer. Hammer uses Smith. Hone adds Security, Compatibility, or Design Reviewers only when their triggers apply. Shape must address compatibility, rollout/migration, rollback, and security where relevant. Quench should use all meaningful available checks. A high-risk Full Forge GitHub delivery ships as draft by default when repository policy enables it; Full Forge alone does not force every PR to be a draft.

## Classification principle

When uncertain between adjacent modes, choose the more conservative mode. Do not choose Full merely because a task is large in line count; choose it because risk/blast radius warrants it.
