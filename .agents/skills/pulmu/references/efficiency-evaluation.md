# Measuring routing efficiency

Read this only when evaluating or changing Pulmu's execution/model policy. Normal development runs do not load it. `benchmark-report.py` is an offline maintainer helper; it does not invoke Pulmu, call a model, collect session logs, or mutate Run Context.

## Compare like-for-like work

Keep the task, starting repository revision, acceptance checks, review requirements, main model/effort, tool versions, permissions, cache conditions, and service tier fixed. Record the policy revision and exact role models/efforts. Use isolated clean copies and counterbalance baseline/candidate order. Run at least three paired repetitions per case; three is a smoke comparison, not statistical proof.

Include representative full-stack cases: a small known bug, a UI + API feature, a database migration, an authorization change, and a failing integration test. Include no-change requests when comparing routing. Predeclare expected behavior and meaningful hidden/regression checks; independently assess escaped defects and missing reviewer assurance. Keep failed runs, retries, blocked runs, and human corrections in the data. Do not select only successful runs or loosen review to improve cost.

Separate the effects when possible: compare new models with the old handoff policy, then compare compact handoffs with models held fixed. A small role-only probe cannot establish end-to-end Pulmu savings.

## Measurement record

Supply one JSON object per complete run in each JSONL file. Pair by `case` and positive integer `sample`. Each file contains one `policy`; baseline and candidate policy IDs differ. `fixture` is an opaque identifier for the same task, base revision, environment, and evaluation conditions; include these in a separate local experiment record. Only paired fixtures must match. Do not put prompts, credentials, raw logs, or personal data in measurements.

Illustrative schema only — these numbers are not benchmark results:

```json
{"case":"api-validation","sample":1,"fixture":"api-validation-v1-node22","policy":"sol61-luna6-compact-v1","checks_passed":true,"review_passed":true,"defects":0,"retries":0,"human_correction_seconds":0,"usage_complete":true,"input_tokens":12000,"cached_input_tokens":8000,"output_tokens":1800,"elapsed_seconds":95}
```

- `checks_passed` and `review_passed` mean the predeclared acceptance checks and required review assurance were satisfied. They are not inferred from the model saying PASS. For a no-change case, predeclare the evidence/assurance required for acceptance.
- `defects` counts independently observed escaped defects. `retries` counts corrective cycles. `human_correction_seconds` includes manual repair and rework.
- `input_tokens` and `output_tokens` include the main session, every child, and retries. Count each request once. Cached input is already included in input; reasoning tokens are already included in output. Do not add either subset again. Do not sum cumulative usage snapshots. If parent usage already includes children, do not add child totals again.
- `usage_complete` is true only when those totals are available for the entire run. If any child/retry usage is missing, set it to false; unknown token fields may be `null`. The report then withholds total-token comparisons instead of treating unknowns as zero.
- `elapsed_seconds` is the run's wall time from request to accepted result or terminal failure, including review and fixes. Do not sum concurrent agent durations.
- Token counts measure consumption, not price or subscription quota. Estimate monetary cost separately using actual per-model usage and current published prices; do not multiply a blended total by a single model's rate.

```bash
python3 <pulmu-skill-dir>/scripts/benchmark-report.py baseline.jsonl candidate.jsonl
```

The report rejects mismatched/duplicate pairs, fixture mismatches, invalid numbers, inconsistent cached counts, and mixed policies. It reports per-case median, total, and maximum elapsed time and all-run token totals, including failures. `observed-improvement` requires at least three pairs per case, complete usage, all acceptance/review checks passing with zero observed defects, lower tokens in every case, and no per-case increase in median time, retries, or human correction time. A paired tail guard also rejects any candidate repetition that is slower by more than `max(5 seconds, 25% of its paired baseline)`, so a single very slow run cannot hide behind an improved median. `tail_regressions` identifies the samples and deltas. Use `--tail-seconds` and `--tail-percent` only with thresholds declared before collecting data; the report records them. The defaults tolerate modest noise and are not a statistical test. Otherwise `not-established` lists the reasons. Descriptive reductions can still appear alongside failed quality gates; they are not qualified savings claims. Undefined percentage comparisons return `null`.

Exit 0 means a valid comparison was produced, including `not-established`; exit 2 means invalid input. For a promotion gate inspect `status`, not just the exit code. Preserve limitations and per-case regressions when reporting results. Unit-test fixtures and prompt byte counts are not model performance measurements.
