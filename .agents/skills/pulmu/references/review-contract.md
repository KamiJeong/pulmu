# Hone review contract

Hone is an independent, read-only review of the actual branch diff and task intent.

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
