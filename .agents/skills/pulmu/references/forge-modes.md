# Forge modes

Forge mode records investigation and risk depth, not stage presence or a fixed agent team. Select the final mode during Shape from the Orchestrator's inspection and any focused scout evidence. It is independent from `direct`, `reviewed`, and `delegated` execution.

`🎨 Pattern` is independent of forge mode. Run it inside Shape whenever Inspect finds meaningful user-facing design impact, even in Quick Forge, and keep its depth proportional to the task. Skip it in any mode when the change has no meaningful user-facing design effect. Read `design-pass.md` only when Pattern runs.

Read `agent-orchestration.md` only when a role will actually be spawned.

## Quick Forge

Use for narrowly scoped, low-risk work such as:

- one/few-file bug fixes
- small UI behavior
- straightforward tests
- local refactors with no public contract change

The Orchestrator may perform Inspect, Shape, Hammer, and self-review directly with no agents when the execution policy is valid. Focused agents remain available when separate evidence is useful. All seven stages still run for the development change.

## Standard Forge

Default for normal features and non-trivial fixes:

- multiple related files
- new application behavior
- API integration without breaking contracts
- meaningful state/data-flow changes

Use enough repository and verification evidence to cover the affected behavior. Standard often benefits from a Test Scout, Architect, or Test Reviewer, but none is required merely by the label. The explicit `testReview` routing flag decides whether Hone requires the Test Reviewer.

## Full Forge

Use when any of these are present:

- database/schema migration
- authentication/authorization/security-sensitive behavior
- breaking API/public contract changes
- cross-cutting architecture changes
- infrastructure/deployment changes
- large dependency/framework migration
- high blast radius or uncertain rollback

Full requires fresh independent review and enough evidence to address compatibility, rollout/migration, rollback, and security where relevant. A Risk Scout or Architect is useful when those questions benefit from independent context. Explicit security and compatibility flags require their specialist reviewers regardless of whether the recorded Forge mode is Quick, Standard, or Full. Quench should use all meaningful available checks. A high-risk Full Forge GitHub delivery ships as draft by default when repository policy enables it; Full Forge alone does not force every PR to be a draft.

## Classification principle

When uncertain between adjacent modes, choose the more conservative mode. Do not choose Full merely because a task is large in line count; choose it because risk/blast radius warrants it.
