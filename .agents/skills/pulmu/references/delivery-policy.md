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

Pulmu never creates a base branch or introduces a new Git Flow. New work branches use `pulmu/<type>/<short-kebab-slug>`, with `feature -> feat` and `bugfix -> fix`; other type names are unchanged. A local or remote collision receives the first available deterministic numeric suffix. A running run blocks a new Ignite. After a terminal run, Ignite may use the current Pulmu branch only to recover verified base provenance before creating a distinct task branch; it never reuses the prior task or evidence, and missing or conflicting provenance fails closed.

## Evidence and delivery metadata

Shape records one or more concrete verification commands with repository-relative working directories. Quench executes that exact plan and records a PASS identity bound to the run ID, branch, base commit, HEAD, and candidate tree. An unavailable command, empty plan, timeout, failed check, or candidate mutation cannot produce PASS. After independent review receipts pass, the Orchestrator records Hone evidence for the same identity. It then creates delivery metadata from the final candidate: a meaningful Conventional Commit title, a user-oriented summary, concrete changes, optional risk reason, and review focus. The metadata helper records an exact changed-path manifest and fingerprint.

Ship starts only when finalized task metadata, exact Quench PASS evidence, complete non-blocking reviewer receipts/Hone evidence, and delivery metadata all describe the same candidate. Smith must leave the real index unchanged. Ship rejects any pre-existing staged content without changing it, stages only recorded paths, and requires the staged tree and resulting commit tree to equal the reviewed candidate before any successful delivery. The order is final-candidate inspection, delivery-metadata generation, staging, cohesive commit, normal push, existing-label discovery, PR creation or reuse, available-label application, and URL reporting. Existing PR lookup is constrained by both head and base; a same-base PR is reconciled to the canonical title and body, while a wrong-base PR is not reused. A GitHub delivery succeeds only with a real pull-request URL for the origin-derived repository. Ship never force-pushes, merges, assigns arbitrary people, or requests arbitrary reviewers. Existing CODEOWNERS and repository-side reviewer automation remain authoritative.

GitHub delivery requires exactly one supported `origin` fetch URL and push URL that resolve to the same host/owner/repository identity. Every GitHub CLI operation explicitly targets that repository, and the returned PR URL is checked against it. Pulmu does not automate a cross-repository pull request when `origin` is a personal fork and `upstream` is the canonical repository. Such repositories must either use the intended writable target as `origin`, or finish locally and perform the fork push and upstream pull request manually.

Commit and PR titles use Conventional Commit style by default and describe the actual diff, not the original prompt. Use scope only when natural. Avoid vague titles such as `update`, `changes`, or `fix stuff`.

The generated PR body contains Summary, Changes, Pulmu Forge, Verification, Risk, Review Focus, and Pulmu Metadata. Verification entries come from the actual Quench log; an unexecuted check is never shown as passed. A legacy `--body-file` is appended as supplemental context and can never replace these canonical sections. Pattern-specific review focus is included only when Pattern ran. High-risk Full Forge delivery is draft by default when configured; Full Forge alone does not force a draft.

## Labels

The desired set is limited to `pulmu`, one type, one forge, one risk, and one to three areas. Type `bugfix` maps to `type: bug`; all other dimensions preserve their metadata values.

By default Pulmu lists repository labels, applies only exact existing matches, and reports missing labels as skipped. It does not change the repository taxonomy. Missing labels are created only when `github.create_missing_labels = true` is explicitly configured. If label discovery is unavailable, every desired label is reported as skipped and PR delivery continues; Pulmu does not guess or create labels without a trustworthy inventory. Individual label-create permission/race failures are reported as skipped, and label-apply failures are reported as unapplied. Neither suppresses a valid PR URL. Labels never influence whether the PR itself is considered created.

## Interrupted delivery recovery

Ship records the run ID, branch, base, candidate tree, and created commit before attempting GitHub push and pull-request operations. When a later GitHub operation fails, the retained metadata permits an exact, clean same-run retry without creating a second commit, including after the run was marked failed or interrupted. Recovery preserves the original terminal history snapshot and records recovered completion separately. The user should repair the external condition—authentication, remote access, permissions, or GitHub availability—and retry Ship. Starting a fresh Ignite is not delivery recovery. Recovery metadata under the Git directory is part of the resume contract and must not be deleted manually.

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
