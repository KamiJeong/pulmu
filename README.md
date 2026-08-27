<p align="center">
  <img src="./assets/pulmu-joseon-forge.png" alt="A blacksmith working beside a traditional bellows in a Joseon-era Korean forge" width="100%">
</p>

# Pulmu 🔥

> **One command starts the whole smithy.**

Pulmu is a Codex CLI workflow skill that turns a task prompt into a reviewed local commit and, when GitHub delivery is available, a pull request. It coordinates repository inspection, implementation, verification, independent review, and delivery without turning those phases into separate user commands.

```text
$pulmu "Add user search and include tests"
```

Ignite, Inspect, Shape, Hammer, Quench, Hone, and Ship are internal forge stages. The user invokes `$pulmu` once; the main Codex session orchestrates the complete run.

## Quick start

Requirements:

- Codex CLI with Skills support
- Git and a Git repository
- Python 3.10 or newer for the standard-library Run Context engine
- the project runtime needed by its own checks, such as Node, Bun, Python, Rust, or Go
- optional authenticated GitHub CLI for pull-request delivery

Clone Pulmu and install it for the current user:

```bash
git clone https://github.com/KamiJeong/pulmu.git
cd pulmu
./install.sh
```

Restart Codex if the skill does not appear immediately. Then open any Git project and invoke Pulmu:

```text
cd ~/projects/my-project
codex

$pulmu "Add a dark mode toggle to the profile screen and include tests"
```

Pulmu always produces a reviewed local commit when the workflow succeeds. A ready GitHub repository additionally receives a pushed branch and pull request; repositories without GitHub delivery finish locally.

## Task Progress UI

Pulmu uses Codex `update_plan` as the persistent human-readable forge checklist. The step text is stable and contains exactly seven items:

```text
🔥 Ignite — Prepare
🔎 Inspect — Explore
📐 Shape — Design
🔨 Hammer — Implement
🌊 Quench — Verify
🪨 Hone — Review
📦 Ship — Deliver
```

The native plan status carries lifecycle state. Pulmu never writes words such as `active`, `pending`, or `completed` into the step text, never adds agents or retries as tasks, and never promotes Pattern to an eighth stage.

A plan may therefore render like this:

```text
✔ 🔥 Ignite — Prepare
✔ 🔎 Inspect — Explore
● 📐 Shape — Design
○ 🔨 Hammer — Implement
○ 🌊 Quench — Verify
○ 🪨 Hone — Review
○ 📦 Ship — Deliver
```

Ordinary progress messages do not repeat that checklist. They show only the current stage and one concrete activity:

```text
📐 Shape
  ● Defining implementation approach
```

At run start, Pulmu prints its workflow identity once:

```text
🔥 Pulmu — Starting the forge workflow
```

The banner is not a plan item or an additional stage.

## The seven forge stages

| Stage | Responsibility | Primary owner |
|---|---|---|
| 🔥 **Ignite** | validate the repository, detect delivery, choose the base, and prepare the work branch | deterministic script + Orchestrator |
| 🔎 **Inspect** | map relevant code, conventions, tests, dependencies, and risk | read-only Scouts |
| 📐 **Shape** | define acceptance, boundaries, verification, and conditional design intent | Orchestrator + read-only Architect/Designer |
| 🔨 **Hammer** | implement the smallest complete source and test change | `pulmu_smith` only |
| 🌊 **Quench** | run available lint, typecheck, test, and build checks | deterministic script + conditional Analyst |
| 🪨 **Hone** | independently review correctness, tests, security, compatibility, and design | read-only Reviewers |
| 📦 **Ship** | create the reviewed commit and complete local or GitHub delivery | deterministic script + Orchestrator |

Every Forge Mode passes through all seven stages. Modes change review and inspection depth, not the stage vocabulary.

| Mode | Inspect | Shape | Hone |
|---|---|---|---|
| **Quick** | Explorer | Orchestrator; Designer when Pattern runs | Reviewer; Design Reviewer when Pattern runs |
| **Standard** | Explorer + Test Scout | Architect; Designer when Pattern runs | Reviewer + Test Reviewer + conditional Design Reviewer |
| **Full** | Standard scouts + Risk Scout | Architect; Designer when Pattern runs | Standard reviewers + evidence-based Security, Compatibility, and Design Reviewers |

Inspect evidence may escalate a run to a deeper mode. A high-risk Full Forge uses a draft PR by configured default; Full Forge alone does not make every PR a draft.

## Orchestration and one-writer safety

```text
Main Codex session (Orchestrator)
  ├─ read-only Scouts
  ├─ read-only Architect / Designer
  ├─ pulmu_smith (sole task-file writer)
  ├─ deterministic Quench
  ├─ read-only Reviewers
  └─ deterministic Ship
```

The Orchestrator owns stage transitions, agent routing, metadata, retries, evidence consolidation, and delivery. Independent read-only roles can run in parallel. Only `pulmu_smith` may edit application, source, or test files, and the same Smith handles Quench and Hone fixes.

`🎨 Pattern` runs inside Shape when the task has meaningful user-facing design impact. It defines hierarchy, interaction states, responsive behavior, accessibility, and visual restraint before Hammer. Backend-only, infrastructure, test-only, internal-refactor, and invisible bug-fix work skips it.

Retry paths reuse the same plan items and the same run ID:

```text
Quench failure  → Hammer → Quench
Hone finding    → Hammer → Quench → Hone
```

Ship remains blocked until Quench passes and Hone has no unresolved high- or medium-severity findings for the exact final diff.

## Persistent Run Context

Pulmu exposes the same forge to humans and machines through separate channels:

```text
$pulmu
   ├─ update_plan
   │    └─ human progress UI
   └─ <git-dir>/pulmu/run.json
        └─ machine-readable runtime state
             ├─ Codex
             ├─ future resume work
             └─ external observability
```

> **update_plan shows the forge to humans. Run Context exposes the forge to machines.**

Ignite creates `<git-dir>/pulmu/run.json`, normally `.git/pulmu/run.json`. The file lives in Git metadata, never enters the working tree, and is never committed. Schema v1 exposes:

- workflow and immutable run ID
- `running`, `completed`, `failed`, or `interrupted` lifecycle state
- sanitized task type and prompt
- Forge Mode, risk, areas, and Pattern usage
- current forge stage and active agents
- base branch, work branch, and delivered commit
- Quench and Hone retry counters
- timestamps, concise safe errors, and validated PR data

Stage changes update Run Context immediately beside the matching native plan transition. Updates use strict validation, expected-run guards, file locking, owner-only permissions, and atomic replacement. Canonical Shape metadata is copied rather than re-inferred.

Terminal snapshots are retained under `<git-dir>/pulmu/runs/<runId>.json`. A replacement Ignite reports and archives an earlier running state only when it can safely initialize the replacement; it never resumes automatically. If a dirty worktree blocks Ignite, the earlier run is reported but preserved because it may still be live. Malformed state fails closed for normal mutations and is quarantined only during explicit new-run initialization.

Inspect current state with either helper:

```bash
bash .agents/skills/pulmu/scripts/run-context.sh show
bash .agents/skills/pulmu/scripts/pulmu-status.sh
```

The full machine contract is documented in [Run Context](./.agents/skills/pulmu/references/run-context.md).

## Git and GitHub delivery

Pulmu respects the repository's existing strategy; it does not impose Git Flow. Base selection follows explicit Pulmu config, repository instructions, the current branch convention, the remote default, then existing `main` or `develop` branches.

Work branches use `pulmu/<type>/<short-kebab-slug>`:

```text
pulmu/feat/user-search
pulmu/fix/login-redirect
pulmu/docs/api-guide
```

Inspect and Shape finalize task metadata once. That same record routes reviewers and drives the commit, PR body, draft decision, and bounded labels. Ship stages only the recorded path manifest and requires exact-diff Quench and Hone evidence.

Local delivery completes after the reviewed commit. GitHub delivery completes only after the branch is pushed and a real pull-request URL is created or reused. Pulmu never merges or force-pushes, and it leaves CODEOWNERS and repository automation in charge of reviewer assignment.

Generated PRs contain Summary, Changes, Pulmu Forge, Verification, Risk, Review Focus, and Pulmu Metadata. Labels are limited to `pulmu`, one type, one forge, one risk, and one to three areas. Missing or unavailable labels are reported but do not invalidate a real PR.

Optional `.pulmu/config.toml` settings use safe defaults:

```toml
[git]
branch_prefix = "pulmu"
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

`git.base_branch` may select an existing base explicitly. The parser accepts only the documented scalar subset, treats configuration as data, and rejects `auto_merge = true` or `force_push = true`. See the [delivery policy](./.agents/skills/pulmu/references/delivery-policy.md).

### GitHub setup checklist

Pulmu selects GitHub delivery only when all of these checks succeed:

- `github.create_pr` is enabled (the default)
- an `origin` remote exists
- GitHub CLI (`gh`) is installed and authenticated
- `gh repo view` can resolve the current repository

Check the repository before starting a GitHub-delivery run:

```bash
gh --version
gh auth login
gh auth status
git remote -v
gh repo view --json nameWithOwner,defaultBranchRef
```

The authenticated account needs permission to push the Pulmu work branch and create or update a pull request in the `origin` repository. Reading labels is enough for the default label behavior; creating missing labels additionally requires label-management permission and must be enabled explicitly.

### How delivery is selected

When the checklist is ready, Ignite selects `PULMU_DELIVERY=github`. If GitHub was not explicitly required and any readiness check fails, Pulmu selects `PULMU_DELIVERY=local` and still finishes with a reviewed local commit. If the task explicitly requires a pull request, missing GitHub setup blocks the run with a recovery message instead of silently falling back. Setting `github.create_pr = false` always selects local delivery.

### Fork and upstream limitation

GitHub delivery currently pushes to `origin` and opens or reuses the pull request in that same repository. A split setup where `origin` is a personal fork and `upstream` is the canonical repository is not yet automated as a cross-repository pull request. In that setup, either make the intended target repository the writable `origin`, or use local delivery and manually push the branch and open the fork-to-upstream pull request.

### Pull requests and labels

Pulmu reuses an existing pull request only when its head and base match the current delivery, then reconciles its title and body with the final reviewed diff. A pull request with a different base is not reused.

Labels use exact repository matches such as `pulmu`, `type: feature`, `forge: standard`, `risk: low`, and `area: frontend`. Missing labels are reported without failing a valid pull request. Pulmu does not create missing labels unless `github.create_missing_labels = true` is explicitly configured.

### Recovering an interrupted GitHub delivery

Ship creates the reviewed commit before it pushes or creates the pull request. If GitHub delivery stops partway through, inspect both the persisted run and Git state:

```bash
bash .agents/skills/pulmu/scripts/pulmu-status.sh
git status --short --branch
git log -1 --oneline
gh pr list --head "$(git branch --show-current)"
```

Repair authentication or remote access without deleting Pulmu state:

```bash
gh auth login
gh auth status
git remote -v
gh repo view
```

If the original Codex session is still active, ask it to retry Ship after the external problem is fixed. Ship records the delivered commit in Git metadata and resumes a matching clean delivery without creating a duplicate commit. If that session has ended, confirm that `pulmu-status.sh` reports `failed` or `interrupted` and that the worktree is clean before rerunning the same `$pulmu` task. Do not manually delete `.git/pulmu` or `.git/pulmu-*` recovery metadata.

## Installation and demo

`./install.sh` installs the skill and agent definitions under:

```text
~/.agents/skills/pulmu/
~/.codex/agents/pulmu-*.toml
```

Codex discovers repository skills under `.agents/skills` and user skills under `~/.agents/skills`. The skill list displays **Pulmu Workflows**; invocation remains `$pulmu`.

Update an existing clone and reinstall the user copy:

```bash
git pull --ff-only
./install.sh
```

Remove the installed user copy without deleting the repository clone:

```bash
./uninstall.sh
```

Create a disposable embedded demo:

```bash
./scripts/create-demo-repo.sh /tmp/pulmu-demo
cd /tmp/pulmu-demo
codex
```

Then run:

```text
$pulmu "Add complete(id) to TaskStore and include tests"
```

An authenticated GitHub CLI can create a private demo repository as well:

```bash
./scripts/create-demo-repo.sh /tmp/pulmu-demo --github pulmu-demo
```

## Safety boundaries

- one application/source/test writer: `pulmu_smith`
- every other custom agent is read-only
- unrelated dirty work blocks Ignite and is never stashed or discarded
- Quench must pass before Ship
- unresolved high/medium Hone findings block Ship
- task metadata is finalized once and reused
- GitHub delivery requires a real PR URL
- no merge, force push, or destructive cleanup
- no credentials, environment dumps, raw logs, or model responses in Run Context

## Repository layout

```text
pulmu/
├── .github/
│   ├── workflows/ci.yml
│   ├── ISSUE_TEMPLATE/
│   └── PULL_REQUEST_TEMPLATE.md
├── .agents/skills/pulmu/
│   ├── SKILL.md
│   ├── VERSION
│   ├── scripts/
│   │   ├── ignite.sh
│   │   ├── metadata.sh
│   │   ├── quench.sh
│   │   ├── ship.sh
│   │   ├── run-context.py
│   │   ├── run-context.sh
│   │   └── pulmu-status.sh
│   └── references/
│       ├── stage-contract.md
│       ├── agent-orchestration.md
│       ├── design-pass.md
│       ├── forge-modes.md
│       ├── review-contract.md
│       ├── delivery-policy.md
│       └── run-context.md
├── .codex/agents/pulmu-*.toml
├── examples/task-store/
├── scripts/create-demo-repo.sh
├── tests/test.sh
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── install.sh
└── uninstall.sh
```

## Development

Run the deterministic integration suite after changing Pulmu scripts or contracts:

```bash
./tests/test.sh
```

The suite does not call a model. It verifies shell and TOML syntax, installation and demo packaging, the agent inventory and one-writer boundary, the exact seven-step progress contract, Forge routing, Pattern behavior, metadata and branch policy, Quench/Hone evidence gates, local and GitHub delivery, Run Context lifecycle and retries, stale and malformed state, redaction, concurrency, history, legacy migration, and linked worktrees.

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the change and pull-request checklist, [SECURITY.md](./SECURITY.md) for private vulnerability reporting, and [CHANGELOG.md](./CHANGELOG.md) for notable project changes.

## License

MIT
