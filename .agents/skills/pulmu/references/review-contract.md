# Hone review contract

Hone is an independent, read-only review of the actual branch diff and task intent. The Orchestrator selects reviewers using `agent-orchestration.md`, runs independent scopes in parallel when useful, and consolidates their evidence before deciding whether to return to Smith.

## Reviewer scopes

- `pulmu_reviewer`: correctness and regression; always runs
- `pulmu_test_reviewer`: missing tests, weak assertions, and validation gaps; Standard and Full
- `pulmu_security_reviewer`: authentication, authorization, sensitive data, and security-sensitive code; Full when relevant
- `pulmu_compat_reviewer`: public API, schema, migration, external integration, and compatibility risk; Full when relevant
- `pulmu_design_reviewer`: Pattern intent, design consistency, responsive behavior, interaction states, accessibility, and visual restraint; whenever Pattern ran

All reviewers remain read-only. Their tasks are not added to `update_plan`.

Reviewer routing and focus consume the canonical metadata finalized after Shape. Security and compatibility flags are evidence-based routing decisions, not fields that Ship re-infers from the finished diff.

## Blocking findings

High or medium severity findings block Ship until fixed and re-verified.

Focus on:

1. correctness and edge cases
2. behavior regressions
3. security/auth/data exposure
4. compatibility/public contracts
5. concurrency/state consistency when relevant
6. missing meaningful tests
7. task scope: required behavior missing or unrelated change added

## Pattern review

When Shape ran `🎨 Pattern`, `pulmu_design_reviewer` reviews the implementation against its recorded brief. Check that:

1. information hierarchy and primary/secondary actions remain clear
2. existing components, tokens, and visual language are reused consistently
3. responsive behavior works at the intended desktop, tablet, mobile, and narrow widths
4. required interaction and content states are present
5. semantic markup, keyboard use, focus, labels, contrast, and necessary ARIA are sound
6. no unnecessary gradients, cards, shadows, rounding, icons, or animation obscure the product's established style

Missing or materially incorrect design intent is high or medium when it harms usability, accessibility, or the requested experience. Route blocking findings through Hammer → Quench → Hone. Do not run this design review for tasks where Pattern was skipped.

## Consolidation

The Orchestrator deduplicates overlapping findings, preserves concrete evidence, and chooses the highest defensible severity. High or medium findings return to the same `pulmu_smith`, then Quench and the applicable Hone reviewers run again. Low findings may remain in the final summary.

## Non-blocking findings

Low-severity maintainability or style suggestions can remain as final notes if they do not hide a real bug.

## Review output

Prefer:

```text
PASS
```

or:

```text
MEDIUM — <finding>
Evidence: <file/symbol/behavior>
Fix: <smallest defensible correction>
```

Avoid vague praise or exhaustive style commentary.
