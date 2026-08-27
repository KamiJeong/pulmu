# Git and GitHub delivery policy

Pulmu does not impose Git Flow. It detects and respects the repository's existing delivery strategy.

## Canonical task metadata

Ignite creates provisional metadata under the repository Git directory. Inspect and Shape decide the values, then the Orchestrator finalizes them exactly once with `scripts/metadata.sh finalize`. Ship reads this record; it must not infer the same fields again.

```yaml
task:
  type: feature
  forge: standard
  risk: medium
areas: [frontend, design]
pattern: true
security_review: false
compatibility_review: false
```

Supported types are `feature`, `bugfix`, `refactor`, `docs`, `test`, and `chore`. Forge is `quick`, `standard`, or `full`; risk is `low`, `medium`, or `high`. Areas are repository-specific lowercase slugs, normally chosen from frontend, backend, database, infra, security, design, api, and testing. Keep one to three relevant areas. Pattern adds `frontend` and `design`; a skipped Pattern never adds design metadata on its own.

Metadata drives review routing and delivery:

```text
Pulmu Metadata
      |
      +-- Type
      +-- Forge
      +-- Risk
      +-- Area
      +-- Pattern
      |
      v
📦 Ship
      |
      +-- Branch
      +-- Commit
      +-- PR Title
      +-- PR Body
      +-- Labels
      |
      v
GitHub Pull Request
```

## Repository strategy and branches

Base-branch precedence is:

1. an existing branch explicitly named by `.pulmu/config.toml`
2. an existing branch explicitly named by repository `AGENTS.md` instructions
3. the current non-Pulmu branch as the observed repository convention
4. the GitHub default branch (or `origin/HEAD`)
5. an existing `main`
6. an existing `develop`

Pulmu never creates a base branch or introduces a new Git Flow. New work branches use `pulmu/<type>/<short-kebab-slug>`, with `feature -> feat` and `bugfix -> fix`; other type names are unchanged. A local or remote collision receives the first available deterministic numeric suffix. An already-active legacy `pulmu/*` branch is reused only when its canonical metadata and `.git/pulmu-*` provenance agree; its recorded base is preserved instead of freshly inferred, and missing or ambiguous provenance fails closed.

## Evidence and delivery metadata

Quench records a PASS fingerprint for the exact diff it verified. After independent review, the Orchestrator records an explicit Hone pass. It then creates delivery metadata from the final diff: a meaningful Conventional Commit title, a user-oriented summary, concrete changes, optional risk reason, and review focus. The metadata helper records an exact changed-path manifest and fingerprint.

Ship starts only when finalized task metadata, exact Quench PASS evidence, non-blocking Hone evidence, and delivery metadata all describe the same working tree. It stages only the recorded changed paths. The order is final-diff inspection, delivery-metadata generation, staging, cohesive commit, normal push, existing-label discovery, PR creation or reuse, available-label application, and URL reporting. Existing PR lookup is constrained by both head and base; a same-base PR is reconciled to the canonical title and body, while a wrong-base PR is not reused. A GitHub delivery succeeds only with a real pull-request URL. Ship never force-pushes, merges, assigns arbitrary people, or requests arbitrary reviewers. Existing CODEOWNERS and repository-side reviewer automation remain authoritative.

GitHub delivery uses `origin` as both the normal push remote and the repository in which it creates or reuses the pull request. Pulmu does not currently automate a cross-repository pull request when `origin` is a personal fork and `upstream` is the canonical repository. Such repositories must either use the intended writable target as `origin`, or finish locally and perform the fork push and upstream pull request manually.

Commit and PR titles use Conventional Commit style by default and describe the actual diff, not the original prompt. Use scope only when natural. Avoid vague titles such as `update`, `changes`, or `fix stuff`.

The generated PR body contains Summary, Changes, Pulmu Forge, Verification, Risk, Review Focus, and Pulmu Metadata. Verification entries come from the actual Quench log; an unexecuted check is never shown as passed. A legacy `--body-file` is appended as supplemental context and can never replace these canonical sections. Pattern-specific review focus is included only when Pattern ran. High-risk Full Forge delivery is draft by default when configured; Full Forge alone does not force a draft.

## Labels

The desired set is limited to `pulmu`, one type, one forge, one risk, and one to three areas. Type `bugfix` maps to `type: bug`; all other dimensions preserve their metadata values.

By default Pulmu lists repository labels, applies only exact existing matches, and reports missing labels as skipped. It does not change the repository taxonomy. Missing labels are created only when `github.create_missing_labels = true` is explicitly configured. If label discovery is unavailable, every desired label is reported as skipped and PR delivery continues; Pulmu does not guess or create labels without a trustworthy inventory. Individual label-create permission/race failures are reported as skipped, and label-apply failures are reported as unapplied. Neither suppresses a valid PR URL. Labels never influence whether the PR itself is considered created.

## Interrupted delivery recovery

Ship records the created commit before attempting GitHub push and pull-request operations. When a later GitHub operation fails, the retained Ship metadata permits an exact, clean retry without creating a second commit. The user should repair the external condition—authentication, remote access, permissions, or GitHub availability—and retry Ship in the same orchestration session. A replacement run must first confirm a terminal `failed` or `interrupted` Run Context and a clean worktree. Recovery metadata under the Git directory is part of the resume contract and must not be deleted manually.

## Configuration

Pulmu uses safe defaults without a config. When present, `.pulmu/config.toml` supports this strict scalar subset:

```toml
[git]
branch_prefix = "pulmu"
base_branch = "main"
conventional_commits = true

[github]
create_pr = true
apply_labels = true
create_missing_labels = false
full_forge_draft = true

[policy]
auto_merge = false
force_push = false
```

The file is parsed as data and is never sourced or evaluated. Unknown keys and malformed values fail closed. `auto_merge = true` and `force_push = true` are rejected because those operations are outside Pulmu's policy.
