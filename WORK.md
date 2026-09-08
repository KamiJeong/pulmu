# Pulmu work state

## Product sentence

Pulmu assesses a coding request, then uses the smallest credible one-writer path to produce a verified local commit with explicit review assurance and optional GitHub delivery.

## Core model

`$pulmu` is the only public command. Advice and no-change results finish before Ignite. Actual development keeps the seven internal stages and stable presentation.

```text
Necessity assessment
  ├─ no change → evidence-backed answer
  └─ development → Ignite → Inspect → Shape
                                  ├─ direct
                                  ├─ reviewed
                                  └─ delegated
                                       ↓
                         one designated writer
                                       ↓
                         Quench → Hone → Ship
```

- The Orchestrator owns routing, transitions, consolidation, retries, and delivery.
- The Orchestrator or `pulmu_smith` is designated as the single task-file writer.
- Tiny low-risk work may use no subagents; medium/high risk requires fresh independent review.
- Security and compatibility flags require their specialist reviewers regardless of Forge depth.
- Pattern remains conditional inside Shape and may be owned by the Orchestrator; Designer is optional.
- Replan preserves work and run identity while invalidating stale routing and evidence.
- Quench and Ship remain deterministic and candidate-bound.

## Next likely work

1. Run real Codex CLI E2E cases for direct, reviewed, delegated, no-change, and design-choice requests.
2. Compare token use, elapsed time, defect findings, and human correction time across paths.
3. Persist structured stage events for Agent Observatory.
4. Add repository-specific verification policy overrides.
