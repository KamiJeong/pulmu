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

## Independent input and receipt

Each reviewer starts in a fresh context. Supply the original task and acceptance conditions, run ID, base branch and resolved commit, current branch and HEAD, exact Quench candidate fingerprint/tree, complete candidate paths/content (including untracked and deleted files), Quench results, and the Pattern brief when applicable. Do not supply Smith discussion, implementation rationale, another reviewer's verdict, or a prior aggregate PASS before the first verdict.

Inspect the candidate recorded by Quench, rather than re-deriving a branch or working-tree diff. With `candidate_head` and `candidate_tree` from Pulmu metadata, use `git diff --binary "$candidate_head" "$candidate_tree"` for the complete change and `git show "$candidate_tree:<path>"` for exact candidate file content. This includes files that were untracked before Quench and preserves deletions.

Before spawning a required reviewer, open its receipt with `metadata.sh review-attempt --role <role> --candidate <fingerprint> --expect-run-id "$RUN_ID"`. Record the returned result with `metadata.sh review`, preserving these fields: role, run ID, candidate, completion (`complete|incomplete`), severity (`none|low|medium|high`), findings, concrete evidence, and limitations. The helper binds the receipt to the current Quench candidate and derives the required reviewer set from finalized mode/flags.

```bash
bash <pulmu-skill-dir>/scripts/metadata.sh review \
  --role "<pulmu_reviewer|pulmu_test_reviewer|pulmu_security_reviewer|pulmu_compat_reviewer|pulmu_design_reviewer>" \
  --candidate "$QUENCH_FINGERPRINT" \
  --completion "<complete|incomplete>" \
  --severity "<none|low|medium|high>" \
  --findings "<PASS or concise finding summary>" \
  --evidence "<file/symbol/behavior checked>" \
  --limitations "<none or unavailable evidence>" \
  --expect-run-id "$RUN_ID"
```

Missing, crashed, timed-out, or malformed output is `incomplete`, never PASS. Permit one repair of result transport/format for that role, then stop Hone. Do not ask the reviewer to change its substantive verdict during a format repair. Hone PASS requires one complete, matching, non-blocking receipt from every required role.

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

Return the structured fields expected above. In `findings`, prefer:

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
