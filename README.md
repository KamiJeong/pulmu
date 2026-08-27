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
  ✓ Repository ready · branch pulmu/user-search
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

## Forge stages

| Stage | Meaning | Owner |
|---|---|---|
| 🔥 **Ignite** | preflight, delivery detection, base/branch preparation | deterministic script + Codex |
| 🔎 **Inspect** | map relevant code, conventions, tests, risks | `pulmu_explorer` read-only subagent |
| 📐 **Shape** | choose forge mode, form the implementation plan, and conditionally run Pattern | main Codex |
| 🔨 **Hammer** | implement the smallest complete change | main Codex (single writer) |
| 🌊 **Quench** | lint/typecheck/test/build and retry fixes when needed | deterministic script + main Codex |
| 🪨 **Hone** | independent correctness/regression/security/test review | `pulmu_reviewer` read-only subagent |
| 📦 **Ship** | commit locally; optionally push and create a GitHub PR | deterministic script + Codex |

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
- **Full Forge** — migrations, auth/security, cross-cutting or breaking changes. When delivered through GitHub, it ships as a **draft PR** by default.

## Requirements

- Codex CLI with Skills support
- Git
- a Git repository
- the project's own runtime/toolchain for Quench (Node/Bun/Python/Rust/Go etc.)

For automatic GitHub delivery, add an `origin` remote and authenticate the optional GitHub CLI (`gh auth status`). Without those, Pulmu completes with a reviewed local commit. Pulmu never force-pushes and never merges a PR.

## Install for your user

```bash
./install.sh
```

This installs:

```text
~/.agents/skills/pulmu/
~/.codex/agents/pulmu-explorer.toml
~/.codex/agents/pulmu-reviewer.toml
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
│           ├── agents/
│           │   └── openai.yaml
│           ├── scripts/
│           │   ├── common.sh
│           │   ├── ignite.sh
│           │   ├── quench.sh
│           │   └── ship.sh
│           └── references/
│               ├── design-pass.md
│               ├── forge-modes.md
│               ├── stage-contract.md
│               └── review-contract.md
├── .codex/
│   ├── config.toml
│   └── agents/
│       ├── pulmu-explorer.toml
│       └── pulmu-reviewer.toml
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

Pulmu v0.1.0 intentionally keeps the workflow boring where boring is good:

- one writer at a time
- Explorer and Reviewer are read-only
- existing uncommitted work blocks Ignite
- Quench must pass before Ship
- unresolved high/medium review findings block Ship
- Full Forge produces a draft PR when using GitHub delivery
- no merge
- no force push
- no destructive cleanup of unrelated user changes

## Development

Run Pulmu's local integration tests:

```bash
./tests/test.sh
```

The tests do not call a model. They verify shell syntax, demo tests, Quench discovery, installer layout, local-only delivery, and GitHub delivery using a bare Git remote plus a fake `gh` command.

## License

MIT
