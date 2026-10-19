# Separate issues in separate worktrees

One run still has one writer. Parallel issues use separate worktrees, branches,
run IDs, metadata, and evidence. A worktree isolates working files and the index;
it does not isolate filesystem permissions, Git objects/refs, network services,
ports, databases, or accounts. Give each run explicit directory ownership and
separate runtime/test resources. Do not launch concurrent writers in one tree.

When the user requests parallel issues, the Orchestrator prepares each independent
issue through the internal Ignite helper:

```bash
bash <skill>/scripts/ignite.sh --worktree /absolute/sibling/path/issue-42 \
  --base main --type bugfix --slug issue-42 "<one issue and its acceptance conditions>"
```

The destination must not exist and must be outside every registered working tree
and the repository's shared Git metadata directory.
Initialization is serialized with a repository-common lock to avoid concurrent
branch allocation races. The resulting runs execute independently afterward.
Existing source edits and a running source run are preserved; the new worktree
starts from committed base content, so source uncommitted changes are not copied.
Without `--worktree`, the existing clean-tree and one-active-run checks still apply.
`--base` is an explicit logical branch choice; no implicit fetch or base update occurs.

Capture `PULMU_WORKTREE`, the actual branch after collision handling, and the run
ID. Every agent brief and subsequent shell call must use that worktree as its
working directory. Start a separate Codex session there when shared-session tools
cannot reliably target a distinct root. Shared terminal `cd` state is insufficient.
Do not share UI instances or evidence files between issues.

For a read-only overview:

```bash
python3 <skill>/scripts/worktrees.py list
```

This reports recorded run status, not proof that a process is still alive. An
initialization failure retains the new worktree for inspection; no task content is
automatically deleted. Inspect its recorded state and repair the prerequisite or
explicitly dispose of it under the user's normal Git workflow.

This feature prepares isolated per-issue runs. It does not fetch an issue backlog,
schedule or distribute issues automatically, aggregate model jobs, resolve
cross-issue dependencies, merge branches, or delete completed worktrees. Dependent
issues need explicit sequencing and a deliberate base. Keep normal review and
delivery gates for each run. If a shared base advances after verification, Ship
requires fresh verification; preserve an already created commit and use the
documented Ship reverification path.
