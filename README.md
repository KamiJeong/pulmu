<p align="center">
  <img src="./assets/pulmu-joseon-forge.png" alt="A blacksmith working beside a traditional bellows in a Joseon-era Korean forge" width="100%">
</p>

# Pulmu 🔥

[English](./README.md) | [한국어](./README.ko.md)

> **One command starts the whole smithy.**

Pulmu is an adaptive Codex CLI workflow skill. It first checks whether a repository change is useful, then takes real development work through one-writer implementation, deterministic verification, proportional review, a local commit, and optional pull-request delivery.

```text
$pulmu "Add user search and include tests"
```

Ignite, Inspect, Shape, Hammer, Quench, Hone, and Ship are internal forge stages. The user invokes `$pulmu` once; the main Codex session orchestrates the complete run.

## User guide

- [Install and start](#quick-start)
- [Describe a task and respond to proposals](#requesting-work)
- [Choose a design direction](#when-you-have-no-ui-plan)
- [Understand execution and completion](#execution-depth-and-results)
- [Follow progress](#task-progress-ui)
- [Configure local or GitHub delivery](#git-and-github-delivery)
- [Handle a stopped run](#when-work-stops-or-requirements-change)
- [Update, uninstall, or try the demo](#installation-and-demo)

## Quick start

Requirements:

- Codex CLI with Skills support
- Git and a Git repository
- Python 3.10 or newer for the standard-library Run Context engine
- the project runtime needed by its own checks, such as Node, Bun, Python, Rust, or Go
- optional authenticated GitHub CLI for pull-request delivery

Independent-review and delegated runs also need the selected agent roles and their configured models to be available. The installer copies the role definitions; it does not grant model access. Browser/rendering tools are needed to produce and verify live UI previews. Pulmu reports unavailable checks rather than claiming they passed.

1. Download Pulmu in your terminal. This example keeps the source in `~/tools/pulmu`, which must not already exist.

```bash
mkdir -p ~/tools
git clone https://github.com/KamiJeong/pulmu.git ~/tools/pulmu
cd ~/tools/pulmu
```

2. **Choose one** installation scope. Replace `~/projects/my-project` with your existing target Git repository.

For one project only:

```bash
./install.sh --local ~/projects/my-project
```

For all projects of the current user:

```bash
./install.sh --global
```

For local installation, complete the Git preparation under [installation scopes](#installation-and-demo). The source checkout and target project are separate directories.

3. Open Codex in the **target project**. Restart Codex if the skill does not appear immediately.

```bash
cd ~/projects/my-project
codex
```

4. Enter this **inside Codex**, not in your shell:

```text
$pulmu "Add a dark mode toggle to the profile screen and include tests"
```

Start implementation from a clean working tree with an existing commit. Configure Git author identity if commits are not yet configured, and install the target project's dependencies so its checks can run. Pulmu does not stash or discard unrelated changes to prepare a run.

If the request is already solved by current behavior or needs only advice, Pulmu explains that result before Ignite and creates no branch, state, or empty commit. A successful development run produces a verified local commit with the recorded review assurance; a ready GitHub repository can additionally receive a pushed branch and pull request.

## Requesting work

Describe the outcome, relevant constraints, and what would count as complete. You do not need to select internal stages, agent names, or a Forge mode. A useful request includes the current problem, desired behavior, important compatibility/design constraints, and delivery preference when you have one.

Enter requests like these inside Codex:

```text
$pulmu "Fix the misspelled Save label in the profile form. Keep the existing layout. Local commit only; do not push or create a PR."

$pulmu "Add customer search by name and email. Include empty and error states and tests for filtering. Open a PR when verification passes."

$pulmu "Check whether a second cache layer is needed. Explain the existing behavior and tradeoffs; do not change files."
```

Pulmu first reads enough evidence to judge necessity. A clear, small change proceeds after a brief explanation. A meaningful difference in behavior, compatibility, cost, or scope gets a recommended option and practical alternatives before implementation. Existing functionality may make a new implementation unnecessary.

Respond in plain language, for example “Use the recommended option,” “Keep the existing API,” or “Choose the design for me.” A consequential unresolved choice waits for your answer; an already accepted or delegated decision does not require another approval. You can add constraints during work. If they invalidate the implementation plan, Pulmu returns to Shape and repeats the affected verification and review.

## When you have no UI plan

You can ask for a feature without knowing design-system names, fonts, or color values:

```text
$pulmu "Build a customer dashboard with revenue, active customers, and recent activity. We have no UI direction. Show a recommended design and an alternative before implementation."

$pulmu "Build the same dashboard. Choose a suitable design for me and proceed; reuse our existing components where possible."
```

For a consequential design choice, Pulmu:

1. Identifies the users, main tasks, content density, platform, and existing conventions.
2. Proposes two viewable directions using the same representative screen, content, and core action, with a recommendation and implementation tradeoffs.
3. Uses disposable previews outside the repository before starting the work branch. A static mock is labelled as such; unavailable preview tools are disclosed.
4. Waits for your choice unless you delegated it, then records the chosen hierarchy, visual rules, states, responsive behavior, and accessibility needs in Pattern inside Shape.
5. Implements and checks the rendered result using the available browser/accessibility tools. A mock does not prove working interactions or accessibility.

An existing CSS framework or component library does not necessarily provide a product-level UI direction. Small UI adjustments generally reuse existing conventions without a two-option design exercise. Feedback such as “too dense” or “too empty” is enough; Pulmu translates it into a concrete revision.

The [Wix examples](https://www.wix.com/studio/blog/design-system-examples) and [Figma examples](https://www.figma.com/resource-library/design-system-examples/) provide discovery candidates, not popularity rankings or guaranteed implementation libraries. Pulmu distinguishes platform guidance, UI systems, ecosystem-specific systems, brand references, and Figma kits. Before recommending adoption, it checks shortlisted candidates against current primary sources for framework support, maintenance, and usage conditions. See the [design selection guide](./.agents/skills/pulmu/references/design-selection.md).

## Execution depth and results

Pulmu chooses two separate things from repository evidence:

| Dimension | Choices | Meaning |
| --- | --- | --- |
| Forge depth | Quick / Standard / Full | How much investigation and risk analysis the change needs |
| Execution path | Direct / Reviewed / Delegated | Who implements and whether review uses a separate context |

Quick fits a bounded low-risk change; Standard fits a normal feature or nontrivial fix; Full fits migrations, security-sensitive changes, breaking contracts, or a broad impact. These labels do not set a fixed agent count. The [execution table below](#the-seven-forge-stages) explains the paths. Medium/high risk and Full Forge require independent review; explicit security/compatibility risks require the corresponding specialists. A missing required reviewer cannot be replaced by self-review.

The main session uses your selected model. Spawned roles use their configured models; choosing a model in the main session does not change every specialist. See [agent routing and model defaults](./.agents/skills/pulmu/references/agent-orchestration.md). Model availability and execution cost depend on your environment; the adaptive structure is not a measured token-saving guarantee.

| Outcome | What you receive |
| --- | --- |
| Advisory / no change | Evidence and an explanation; no branch, Forge stages, or commit |
| Local development | Implemented change, verification results, explicit self/independent review assurance, branch and commit |
| GitHub development | The local result plus a pushed branch and a real PR URL |
| Stopped run | The failed stage, concrete reason, preserved work, and a recovery action; no claim of successful delivery |

Completion reports include Forge depth, execution path, writer, checks, review assurance, commit, and optional PR URL. **Self-review means the implementing session checked its own candidate. Independent review means a separate fresh context reviewed it.** Neither is a claim that every possible defect was found. Checks that were unavailable remain identified as limitations.

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
| 🔎 **Inspect** | map relevant code, conventions, tests, dependencies, and risk | Orchestrator + optional read-only Scouts |
| 📐 **Shape** | define acceptance, boundaries, verification, routing, and conditional design intent | Orchestrator + optional read-only Architect/Designer |
| 🔨 **Hammer** | implement the smallest complete source and test change | designated Orchestrator or `pulmu_smith` |
| 🌊 **Quench** | run the concrete, bounded verification plan selected in Shape | deterministic script + conditional Analyst |
| 🪨 **Hone** | record an explicit self-review or fresh independent review of the exact candidate | Orchestrator or read-only Reviewers |
| 📦 **Ship** | create the reviewed commit and complete local or GitHub delivery | deterministic script + Orchestrator |

Every development run passes through all seven stages. Forge modes record depth; they do not prescribe an agent count.

| Execution | Writer | Assurance | Typical use |
|---|---|---|---|
| **Direct** | Orchestrator | explicit self-review | bounded low-risk changes; zero agents allowed |
| **Reviewed** | Orchestrator | fresh independent review | continuous implementation context with separate verification of the result |
| **Delegated** | Orchestrator or Smith | fresh independent review | broader investigation or a separate writer adds value |

Medium/high risk and Full Forge always require independent review. Explicit security and compatibility flags require their specialist reviewer regardless of Forge mode. A high-risk Full Forge uses a draft PR by configured default.

## Orchestration and one-writer safety

```text
Main Codex session (Orchestrator)
  ├─ optional read-only Scouts / Architect / Designer
  ├─ one designated writer (Orchestrator or pulmu_smith)
  ├─ deterministic Quench
  ├─ read-only Reviewers
  └─ deterministic Ship
```

The Orchestrator owns stage transitions, agent routing, metadata, retries, evidence consolidation, and delivery. Each run designates exactly one writer; independent read-only roles run only when their evidence is worth the handoff cost. The same writer handles Quench and Hone fixes.

`🎨 Pattern` runs inside Shape when the task has meaningful user-facing design impact. The Orchestrator may own it; Designer is optional. When no product-level design direction exists, Pulmu proposes relevant, viewable same-content directions and treats public example lists as discovery seeds rather than popularity rankings. It verifies shortlisted implementation candidates against current primary sources.

Retry paths reuse the same plan items and the same run ID:

```text
Quench failure  → Hammer → Quench
Hone finding    → Hammer → Quench → Hone
```

Retry admission is deterministic and run-wide: at most three Quench fixes and two Hone refinements. Recording a retry atomically returns to Hammer and invalidates downstream evidence.

Ship remains blocked until Quench passes and every required receipt matches the exact candidate with no unresolved high- or medium-severity finding. A `pulmu_self_review` receipt cannot satisfy an independent-review route.

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

Ignite creates `<git-dir>/pulmu/run.json`, normally `.git/pulmu/run.json`. The file lives in Git metadata, never enters the working tree, and is never committed. Schema v2 exposes:

- workflow and immutable run ID
- `running`, `completed`, `failed`, or `interrupted` lifecycle state
- sanitized task type and prompt
- Forge Mode, risk, areas, and Pattern usage
- execution path, designated writer, review assurance, and specialist routing
- current forge stage and active agents
- base branch, work branch, and delivered commit
- Quench and Hone retry counters
- timestamps, concise safe errors, and validated PR data

Stage changes update Run Context immediately beside the matching native plan transition. Updates use strict validation, expected-run guards, file locking, owner-only permissions, and atomic replacement. Canonical Shape metadata is copied rather than re-inferred.

Terminal snapshots are retained under `<git-dir>/pulmu/runs/<runId>.json`. A running state blocks a replacement Ignite until it is explicitly completed, failed, or interrupted. A fresh task after a terminal run gets a distinct run ID, prompt, branch, and evidence. If a dirty worktree blocks Ignite, the earlier run is reported but preserved because it may still be live. Malformed state fails closed for normal mutations and is quarantined only during explicit new-run initialization.

From the target project, inspect current state using the installed helper:

```bash
bash ~/.agents/skills/pulmu/scripts/run-context.sh show
bash ~/.agents/skills/pulmu/scripts/pulmu-status.sh
```

For a `--local` or repository-embedded copy, use `.agents/skills/pulmu/scripts/` instead. The current working directory selects the target repository; the script path selects the installed or embedded Pulmu copy.

The full machine contract is documented in [Run Context](./.agents/skills/pulmu/references/run-context.md).

## Git and GitHub delivery

Pulmu respects the repository's existing strategy; it does not impose Git Flow. On a recorded Pulmu work branch, it verifies the saved branch/base/run identity and preserves the recorded base for the next task. Otherwise, base selection follows explicit Pulmu config, repository instructions, the current branch convention, the remote default, then existing `main` or `develop` branches.

Work branches use `<type>/<short-kebab-slug>`:

```text
feat/user-search
fix/login-redirect
docs/api-guide
```

An explicit user name takes priority, followed by explicit repository naming instructions, then the default above. For example, ask for `feature/PROJ-123-customer-search` when your team requires that format. Pulmu does not infer a rule from a few existing branches or invent an issue ID. The Orchestrator passes the complete name to the internal Ignite helper using `--branch`; users still invoke only `$pulmu`.

The default `git.branch_prefix = ""` adds no namespace. Set it to `"pulmu"` to retain `pulmu/feat/customer-search`, or another simple namespace for your team. Explicit complete names override this setting. Local and remote collisions receive a numeric suffix such as `-2`; use the final branch reported by Pulmu.

This policy affects newly created branches only. Existing branches are not renamed. Ownership and base recovery use saved provenance, not the prefix, so a human-created `pulmu/...` branch is not automatically a Pulmu run, and a recorded branch without that prefix can still be recognized. Conflicting matching records block creation; deleting all records does not let Pulmu reconstruct ownership from the name.

Inspect and Shape finalize task metadata and a concrete working-directory/command verification plan once. That same record routes reviewers and drives the commit, PR body, draft decision, and bounded labels. Quench binds evidence to the run, branch, base, HEAD, and candidate tree. The designated writer leaves the real index unchanged; Ship rejects any pre-staged content and requires the staged and committed trees to equal the reviewed candidate.

Local delivery completes after the reviewed commit. GitHub delivery completes only after the branch is pushed and a real pull-request URL is created or reused. Pulmu never merges or force-pushes, and it leaves CODEOWNERS and repository automation in charge of reviewer assignment.

Generated PRs contain Summary, Changes, Pulmu Forge, Verification, Risk, Review Focus, and Pulmu Metadata. Labels are limited to `pulmu`, one type, one forge, one risk, and one to three areas. Missing or unavailable labels are reported but do not invalidate a real PR.

Optional `.pulmu/config.toml` settings use safe defaults:

```toml
[git]
branch_prefix = ""
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

For local-only operation, say “local commit only; do not push or create a PR” in your request, or set `create_pr = false` under `[github]`. Prepare repository configuration before starting the run and keep the working tree clean. With the default configuration, a ready GitHub setup may result in a push and PR; delivery is not a separate stage command you must enter.

### GitHub setup checklist

Pulmu selects GitHub delivery only when all of these checks succeed:

- `github.create_pr` is enabled (the default)
- an `origin` remote exists
- its single fetch and push URLs resolve to the same GitHub repository
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

GitHub delivery pins every CLI operation and the validated PR URL to the repository resolved from matching `origin` fetch/push URLs. A split setup where `origin` is a personal fork and `upstream` is the canonical repository is not automated as a cross-repository pull request. In that setup, either make the intended target repository the writable `origin`, or use local delivery and manually push the branch and open the fork-to-upstream pull request.

### Pull requests and labels

Pulmu reuses an existing pull request only when its head and base match the current delivery, then reconciles its title and body with the final reviewed diff. A pull request with a different base is not reused.

Labels use exact repository matches such as `pulmu`, `type: feature`, `forge: standard`, `risk: low`, and `area: frontend`. Missing labels are reported without failing a valid pull request. Pulmu does not create missing labels unless `github.create_missing_labels = true` is explicitly configured.

### Recovering an interrupted GitHub delivery

Ship creates the reviewed commit before it pushes or creates the pull request. If GitHub delivery stops partway through, inspect both the persisted run and Git state:

```bash
bash ~/.agents/skills/pulmu/scripts/pulmu-status.sh  # --local: use .agents/skills/pulmu/scripts/pulmu-status.sh
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

Ask the Orchestrator to retry Ship after the external problem is fixed. Ship resumes only the same run's recorded commit, branch, base, and candidate from a clean worktree, even when that Ship was marked failed or interrupted; it does not create a duplicate commit. Do not start a fresh Ignite for delivery recovery, and do not manually delete `.git/pulmu` or `.git/pulmu-*` recovery metadata.

## When work stops or requirements change

Inspect the reported stage and current state first. Tell the same Codex session what changed or which prerequisite you repaired. The Orchestrator runs the internal helpers; you do not need to invoke seven separate commands or edit state files.

| Situation | What to do |
| --- | --- |
| Dirty working tree before Ignite | Finish or separately preserve your existing work, then retry from a clean tree. Pulmu will not stash, reset, or delete it. |
| An earlier run is still `running` | Check whether its session is live. Ask that session to continue or explicitly interrupt the old run after confirming it is no longer active. Do not replace its state blindly. |
| Missing tool, dependency, access, or timeout | Repair the reported prerequisite. An environment problem is not automatically an implementation fix. |
| Quench or Hone finds a code issue | Let the designated writer correct it within the bounded retries. Exhausted retries stop delivery and preserve the branch. |
| New scope or risk during an active run | Explain the change. The Orchestrator uses explicit `replan` before Ship, preserving the work and run ID while invalidating the old plan and evidence. |
| Required independent reviewer unavailable | Restore the required role/model access. Self-review cannot substitute for the missing assurance. |
| GitHub fails after the commit | Follow [Ship recovery](#recovering-an-interrupted-github-delivery); reuse the recorded commit instead of starting a new run. |

Example follow-up inside Codex:

```text
The change must also support the existing public API. Reassess the current plan, preserve the work, and repeat the required checks and review.
```

`replan` operates on an active run before Ship; it is not a universal resume command for failed or interrupted runs. Automatic recovery of arbitrary stopped development sessions is not guaranteed. For those cases, use the reported preserved branch and recovery action; GitHub Ship recovery is the specifically supported same-commit recovery path.

## Installation and demo

Run the installer from your Pulmu checkout and choose the scope:

| Scope | Install or update | Remove |
| --- | --- | --- |
| One project | `./install.sh --local /path/to/project` | `./uninstall.sh --local /path/to/project` |
| Current user | `./install.sh --global` | `./uninstall.sh --global` |

No arguments retain the current-user default. `--local` requires an existing project directory; use the target repository root. It installs:

```text
<project>/.agents/skills/pulmu/
<project>/.codex/agents/pulmu-*.toml
```

Local installation preserves the project's `.codex/config.toml`, other skills and agents, and user-wide settings. Launch Codex in the target project. Commit the installed files to share them with the team, or exclude newly installed, untracked paths through Git's local exclude file before starting a run. Ignore rules do not hide changes to files already tracked. Installation does not change Git ignore rules.

For personal use where installed files are still untracked, run this once. For team use, review and commit the installed files instead.

```bash
cd ~/projects/my-project
printf '\n/.agents/skills/pulmu/\n/.codex/agents/pulmu-*.toml\n' >> "$(git rev-parse --git-path info/exclude)"
git status --short
```

The Pulmu checkout itself already embeds these files: installing locally into that checkout is a no-op, and uninstalling from it is refused to protect the source.

Current-user installation uses:

```text
~/.agents/skills/pulmu/
~/.codex/agents/pulmu-*.toml
```

Codex supports [project skills](https://learn.chatgpt.com/docs/build-skills) and [project agent definitions](https://learn.chatgpt.com/docs/agent-configuration/subagents). The skill list displays **Pulmu Workflows**; invocation remains `$pulmu`. A local installation does not remove an existing global copy; both same-name skills may appear. If you want only project-local availability, remove the user copy explicitly with `./uninstall.sh --global`.

Update from the **Pulmu source checkout**. This example updates a local installation:

```bash
cd ~/tools/pulmu
git pull --ff-only
./install.sh --local ~/projects/my-project
```

For global installation, replace the final command with `./install.sh --global`. Reinstallation replaces the installed skill directory and bundled agent definitions, so keep customizations in your maintained checkout. Files are prepared before replacement, and failed replacements attempt to restore the previous installation. If the checkout has local changes, reconcile them before pulling. Repository edits alone do not update installed copies.

Remove a local installation:

```bash
cd ~/tools/pulmu
./uninstall.sh --local ~/projects/my-project
```

To remove the global copy, replace the final command with `./uninstall.sh --global`. Repeat local removal for each project where you installed Pulmu. Restart Codex afterward. If installation files were tracked by Git, review and commit their deletion. Manually added exclude rules can be removed separately.

Uninstalling preserves the downloaded source at `~/tools/pulmu`, project work, commits, and run history. If you no longer need the source, remove all installed copies first, check for source changes you want to keep, then delete that directory.

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

- one designated task-file writer per run: Orchestrator or `pulmu_smith`
- every other custom agent is read-only
- unrelated dirty work blocks Ignite and is never stashed or discarded
- Quench must pass before Ship
- self-review and independent-review receipts remain distinct; unresolved high/medium Hone findings block Ship
- task and execution metadata are finalized once and reused unless explicit replan invalidates downstream evidence
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
│       ├── design-selection.md
│       ├── forge-modes.md
│       ├── review-contract.md
│       ├── delivery-policy.md
│       └── run-context.md
├── .codex/agents/pulmu-*.toml
├── examples/task-store/
├── scripts/create-demo-repo.sh
├── tests/test.sh
├── README.md
├── README.ko.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── install.sh
└── uninstall.sh
```

## Development

Run the deterministic integration suite after changing Pulmu scripts or contracts:

The repository tests need Python 3.11 or newer for `tomllib`, plus Node.js/npm for the example fixture. This differs from the Run Context engine's Python 3.10 minimum for normal use.

```bash
./tests/test.sh
```

The suite does not call a model. It verifies shell and TOML syntax, installation and demo packaging, the adaptive one-writer boundary, the exact seven-step progress contract, routing and Pattern behavior, metadata and branch policy, Quench/Hone evidence gates, local and GitHub delivery, Run Context lifecycle and retries, replanning, stale and malformed state, redaction, concurrency, history, legacy migration, and linked worktrees.

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the change and pull-request checklist, [SECURITY.md](./SECURITY.md) for private vulnerability reporting, and [CHANGELOG.md](./CHANGELOG.md) for notable project changes.

## License

MIT
