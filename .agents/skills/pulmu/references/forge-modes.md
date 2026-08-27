# Forge modes

Forge mode controls depth, not stage presence.

## Quick Forge

Use for narrowly scoped, low-risk work such as:

- one/few-file bug fixes
- small UI behavior
- straightforward tests
- local refactors with no public contract change

Shape should be brief. Hone can be focused on the affected behavior. All seven stages still run.

## Standard Forge

Default for normal features and non-trivial fixes:

- multiple related files
- new application behavior
- API integration without breaking contracts
- meaningful state/data-flow changes

Use a concrete plan, normal verification, and full correctness/regression review.

## Full Forge

Use when any of these are present:

- database/schema migration
- authentication/authorization/security-sensitive behavior
- breaking API/public contract changes
- cross-cutting architecture changes
- infrastructure/deployment changes
- large dependency/framework migration
- high blast radius or uncertain rollback

Shape must address compatibility, rollout/migration, rollback, and security where relevant. Quench should use all meaningful available checks. Hone should be especially skeptical. Ship as draft by default.

## Classification principle

When uncertain between adjacent modes, choose the more conservative mode. Do not choose Full merely because a task is large in line count; choose it because risk/blast radius warrants it.
