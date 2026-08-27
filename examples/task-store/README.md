# Pulmu TaskStore demo

Baseline demo for a real `$pulmu` run.

Suggested task:

```text
$pulmu "Add complete(id) to TaskStore. Return false for an unknown ID; otherwise set completed=true and return true. Add tests too."
```

Expected result: Pulmu creates a branch, implements the method and tests, runs `npm test`, reviews the diff, and creates a local commit. If GitHub delivery is available, it also pushes and opens a PR.
