<p align="center">
  <img src="./assets/pulmu-joseon-forge.png" alt="A blacksmith working beside a traditional bellows in a Joseon-era Korean forge" width="100%">
</p>

# Pulmu 🔥

> **`$pulmu` fires up the whole forge. Ignite, Inspect, Shape, Hammer, Quench, Hone, and Ship are the stages within it.**

**Pulmu turns a task prompt into a reviewed local commit from inside Codex CLI, with optional GitHub pull request delivery.**

Named after the Korean bellows that keeps a traditional forge burning, Pulmu treats software delivery as a disciplined craft: understand the material, shape it carefully, test it under pressure, refine it, and ship it.

```text
$pulmu "Add user search and include tests"

🔥 Pulmu — Starting the forge workflow

🔥 Ignite — Preparing the forge
  ✓ Repository ready · branch pulmu/feat/user-search
🔎 Inspect — Exploring the repository
  ✓ Relevant code, tests, and conventions mapped
📐 Shape — Forming the plan
  ✓ Implementation approach defined
  ✓ 🎨 Pattern — responsive layout and interaction states defined
🔨 Hammer — Forging the change
  ✓ Code and tests implemented
🌊 Quench — Verifying the work
  ✓ Lint, typecheck, tests, and build passed
🪨 Hone — Refining the result
  ✓ Review passed
📦 Ship — Preparing delivery
  ✓ Commit and selected delivery completed

🔥 Pulmu complete
   Commit: abc1234
   PR: https://github.com/.../pull/123
```

Pulmu is intentionally **one user-facing skill**. You invoke `$pulmu` once; Codex orchestrates the full forge. The stages are not seven commands you must manually run.

The one-line `🔥 Pulmu — Starting the forge workflow` banner identifies the workflow at run start. It is not an additional task or forge stage.

## Agent orchestration

```text
Orchestrator
  ↓
Scouts
  ↓
Architect / Designer
  ↓
Smith
  ↓
Quench
  ↓
Independent Reviewers
  ↓
Ship
```

Orchestrator decides. Scouts investigate. Architect and Designer shape. Smith forges. Quench verifies. Reviewers inspect. Ship delivers.

The main Codex session owns the native progress plan, Forge Mode, stage transitions, agent routing, evidence consolidation, retries, and delivery. `pulmu_smith` is the sole application/source/test writer. All Scouts, Architect, Designer, Failure Analyst, and Reviewers are read-only. Independent read-only work can run in parallel; Pulmu never runs competing writers in one working tree.

## Forge stages

| Stage | Meaning | Owner |
|---|---|---|
| 🔥 **Ignite** | preflight, delivery detection, base/branch preparation, provisional mode | deterministic script + Orchestrator |
| 🔎 **Inspect** | map relevant code, conventions, tests, and risk | read-only Scouts |
| 📐 **Shape** | form the architecture brief and conditionally run Pattern | Orchestrator + read-only Architect/Designer |
| 🔨 **Hammer** | implement the smallest complete change | `pulmu_smith` only |
| 🌊 **Quench** | lint/typecheck/test/build; analyze nontrivial failures when needed | deterministic script + conditional read-only Analyst |
| 🪨 **Hone** | independently review correctness, tests, security, compatibility, and design | read-only Reviewers |
| 📦 **Ship** | commit locally; optionally push and create a GitHub PR | deterministic script + Orchestrator |

### Status language

Pulmu uses a small, consistent terminal vocabulary:

```text
● current activity
✓ completed result
✗ failure
↻ retry/refinement
• sub-task
⚠ warning
```

### Conditional design pass

`🎨 Pattern — Designing the experience` runs inside Shape only when Inspect finds meaningful user-facing design impact. It reuses the repository's design language and defines hierarchy, interaction states, responsive behavior, accessibility, and visual restraint before Hammer writes code. Backend-only, infrastructure, test-only, internal refactor, and invisible bug-fix work skips Pattern.

Pattern never becomes an eighth top-level task:

```text
✓ 🔥 Ignite
✓ 🔎 Inspect
● 📐 Shape
○ 🔨 Hammer
○ 🌊 Quench
○ 🪨 Hone
○ 📦 Ship

🎨 Pattern — Designing the experience
  ● Defining hierarchy, interaction, responsive behavior, and accessibility
```

## Forge modes

Every mode still goes through **all seven stages**. Only the depth changes.

- **Quick Forge** — small, low-risk, narrowly scoped changes.
- **Standard Forge** — normal features and bug fixes.
- **Full Forge** — migrations, auth/security, cross-cutting or breaking changes. A **high-risk** Full Forge ships as a draft PR by configured default; Full alone does not force draft status.

| Mode | Inspect | Shape | Hammer | Hone |
|---|---|---|---|---|
| Quick | Explorer | Orchestrator; Designer only for Pattern | Smith | Reviewer; Design Reviewer when Pattern ran |
| Standard | Explorer + Test Scout | Architect; Designer only for Pattern | Smith | Reviewer + Test Reviewer; Design Reviewer when Pattern ran |
| Full | Explorer + Test Scout + Risk Scout | Architect; Designer only for Pattern | Smith | Standard reviewers plus conditional Security and Compatibility Reviewers; Design Reviewer when Pattern ran |

Pulmu uses Luna/medium for narrow repetitive inspection, Terra/medium-or-high for exploration and review, and Sol/high for architecture, design, implementation, and critical review. Only explicitly high-risk authentication, authorization, payment, destructive migration, data-loss, cryptography, concurrency, or public-API-breaking work may escalate Architect or Security Reviewer to `xhigh`; the default workflow never uses `max`.

## Persistent Run Context

Pulmu exposes progress to people and machines without changing the seven-stage workflow:

```text
$pulmu
   │
   ├── update_plan
   │     └─ Human progress UI
   │
   └── Pulmu Run Context
         └─ Machine-readable workflow state
                 │
                 ├─ Codex
                 ├─ future resume
                 └─ Observatory
```

> **update_plan shows the forge to humans. Run Context exposes the forge to machines.**

Ignite creates `<git-dir>/pulmu/run.json` (normally `.git/pulmu/run.json`). Because it is Git metadata, it never enters the working tree or a commit. The schema records workflow and run identity, lifecycle status, sanitized task metadata, Forge/risk/areas/Pattern decisions, the current seven-stage forge stage, active agents, branch and commit, retry counters, timestamps, concise errors, and a validated PR URL when available. Completed, failed, and interrupted snapshots are retained under `<git-dir>/pulmu/runs/`.

Stage and agent changes are deterministic helper mutations coordinated with the existing `update_plan` transitions. Retry loops keep one run ID and record the real sequences (`Quench → Hammer → Quench` and `Hone → Hammer → Quench → Hone`). Canonical Shape metadata is copied rather than re-inferred. Local delivery completes after its reviewed commit; GitHub delivery completes only after a real PR is created or reused.

If Ignite can safely initialize a replacement and finds a previous `running` state, it reports and archives it as interrupted before creating a new run; it never resumes automatically. When a dirty working tree blocks Ignite, the existing run is reported but left unchanged because it may still have a live Smith. State updates use validation, locking, owner-only permissions, and atomic writes. Malformed state fails closed for ordinary mutations and is quarantined only when a new Ignite explicitly initializes a run.

Inspect the current state as JSON or a concise developer view:

```bash
bash .agents/skills/pulmu/scripts/run-context.sh show
bash .agents/skills/pulmu/scripts/pulmu-status.sh
```

See [the Run Context contract](./.agents/skills/pulmu/references/run-context.md).

## Requirements

- Codex CLI with Skills support
- Git
- Python 3.10 or newer (standard library only, for Run Context)
- a Git repository
- the project's own runtime/toolchain for Quench (Node/Bun/Python/Rust/Go etc.)

For automatic GitHub delivery, add an `origin` remote and authenticate the optional GitHub CLI (`gh auth status`). Without those, Pulmu completes with a reviewed local commit. Pulmu never force-pushes and never merges a PR.

## Git and GitHub delivery policy

> **Pulmu does not impose Git Flow. It detects and respects the repository's existing delivery strategy.**

Ignite detects an existing base branch from explicit Pulmu config, repository instructions, the current convention, GitHub's default, then existing `main` or `develop`. Work branches use `pulmu/<type>/<short-kebab-slug>` such as `pulmu/feat/user-search`, `pulmu/fix/login-redirect`, or `pulmu/docs/api-guide`. Local and remote name collisions receive a safe numeric suffix. Active legacy Pulmu branches retain their recorded base and fail closed when canonical metadata and `.git` provenance conflict.

Inspect and Shape decide task metadata once:

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

The same record drives review routing and every Ship artifact:

```text
Pulmu Metadata
      |
      +-- Type / Forge / Risk / Area / Pattern
      |
      v
📦 Ship
      |
      +-- Branch / Commit / PR Title / PR Body / Labels
      |
      v
GitHub Pull Request
```

Ship begins only after Quench PASS and non-blocking Hone evidence match the exact final diff. It generates a meaningful Conventional Commit/PR title, stages only expected paths, creates one cohesive commit, normally pushes, and reuses only a PR matching both head and base. Reused PRs receive the canonical title/body; a supplied `--body-file` is supplemental and cannot replace required sections. A GitHub Ship completes only when a real PR URL is returned. It does not merge, force-push, or invent reviewers/assignees.

Generated PRs include Summary, Changes, the seven-stage Pulmu Forge result, actual Verification evidence, Risk, Review Focus, and Pulmu Metadata. Labels are bounded to `pulmu`, one `type:*`, one `forge:*`, one `risk:*`, and one to three relevant `area:*` labels. By default, missing labels are skipped and reported; if discovery, creation, or application of labels fails, the label failure is reported while a valid PR delivery still completes. Pulmu does not rewrite the repository taxonomy.

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

`git.base_branch` may explicitly select an existing branch. The parser accepts only the documented scalar subset and never sources or evaluates the file. Unsafe `auto_merge = true` or `force_push = true` values are rejected. See [the full delivery contract](./.agents/skills/pulmu/references/delivery-policy.md).

## Install for your user

```bash
./install.sh
```

This installs:

```text
~/.agents/skills/pulmu/
~/.codex/agents/pulmu-*.toml
```

Restart Codex if `$pulmu` does not appear immediately. The skill list shows it as **Pulmu Workflows**, while the invocation remains `$pulmu`.

Then, from any Git project:

```bash
cd ~/projects/my-project
codex
```

Inside Codex:

```text
$pulmu "Add a dark mode toggle to the profile screen and include tests"
```

Codex officially discovers repo skills under `.agents/skills` and user skills under `~/.agents/skills`. This package can be installed globally as above or checked directly into a repository.

## Zero-install demo

Create a disposable local demo repository with Pulmu embedded:

```bash
./scripts/create-demo-repo.sh /tmp/pulmu-demo
cd /tmp/pulmu-demo
codex
```

Then:

```text
$pulmu "Add complete(id) to TaskStore. Return false for an unknown ID; otherwise set completed=true and return true. Add tests too."
```

To create a **private GitHub demo repo** automatically (requires authenticated `gh`):

```bash
./scripts/create-demo-repo.sh /tmp/pulmu-demo --github pulmu-demo
```

Then enter Codex in `/tmp/pulmu-demo` and invoke `$pulmu`.

## Repository layout

```text
pulmu/
├── .agents/
│   └── skills/
│       └── pulmu/
│           ├── SKILL.md
│           ├── VERSION
│           ├── agents/
│           │   └── openai.yaml
│           ├── scripts/
│           │   ├── common.sh
│           │   ├── ignite.sh
│           │   ├── metadata.sh
│           │   ├── run-context.py
│           │   ├── run-context.sh
│           │   ├── pulmu-status.sh
│           │   ├── quench.sh
│           │   └── ship.sh
│           └── references/
│               ├── agent-orchestration.md
│               ├── delivery-policy.md
│               ├── design-pass.md
│               ├── forge-modes.md
│               ├── run-context.md
│               ├── stage-contract.md
│               └── review-contract.md
├── .codex/
│   ├── config.toml
│   └── agents/
│       ├── pulmu-explorer.toml
│       ├── pulmu-test-scout.toml
│       ├── pulmu-risk-scout.toml
│       ├── pulmu-architect.toml
│       ├── pulmu-designer.toml
│       ├── pulmu-smith.toml
│       ├── pulmu-failure-analyst.toml
│       ├── pulmu-reviewer.toml
│       ├── pulmu-test-reviewer.toml
│       ├── pulmu-security-reviewer.toml
│       ├── pulmu-compat-reviewer.toml
│       └── pulmu-design-reviewer.toml
├── assets/
│   └── pulmu-joseon-forge.png
├── examples/task-store/
├── scripts/create-demo-repo.sh
├── tests/test.sh
├── .gitignore
├── AGENTS.md
├── install.sh
└── uninstall.sh
```

## Safety boundaries

Pulmu intentionally keeps the workflow boring where boring is good:

- one writer at a time: `pulmu_smith`
- every other custom agent is read-only
- existing uncommitted work blocks Ignite
- Quench must pass before Ship
- unresolved high/medium review findings block Ship
- high-risk Full Forge produces a draft PR by configured default
- no merge
- no force push
- no destructive cleanup of unrelated user changes

## Development

Run Pulmu's local integration tests:

```bash
./tests/test.sh
```

The tests do not call a model. They verify shell and TOML syntax, the exact agent inventory and writer boundary, skill/reference consistency, metadata propagation, base and branch policy, safe configuration, Quench/Hone delivery gates, local-only delivery, label handling, draft policy, and GitHub delivery using a bare Git remote plus a fake `gh` command. Run Context coverage includes schema creation, stage/agent synchronization, both retry paths, local and GitHub completion, failure/interruption, stale and malformed state, credential redaction, atomic concurrent updates, history, and linked worktrees.

## License

MIT
