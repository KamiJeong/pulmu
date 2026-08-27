<p align="center">
  <img src="./assets/pulmu-joseon-forge.png" alt="A blacksmith working beside a traditional bellows in a Joseon-era Korean forge" width="100%">
</p>

# Pulmu 🔥

> **`$pulmu` fires up the whole forge. Ignite, Inspect, Shape, Hammer, Quench, Hone, and Ship are the stages within it.**

**Pulmu turns a task prompt into a reviewed GitHub pull request from inside Codex CLI.**

Named after the Korean bellows that keeps a traditional forge burning, Pulmu treats software delivery as a disciplined craft: understand the material, shape it carefully, test it under pressure, refine it, and ship it.

```text
$pulmu "Add user search and include tests"

🔥 Ignite   Preparing the forge...
🔎 Inspect  Exploring the repository...
📐 Shape    Forming the implementation plan...
🔨 Hammer   Implementing...
🌊 Quench   Running verification...
🪨 Hone     Reviewing and refining...
📦 Ship     Creating the pull request...

🔥 Pulmu complete
   PR https://github.com/.../pull/123
```

Pulmu is intentionally **one user-facing skill**. You invoke `$pulmu` once; Codex orchestrates the full forge. The stages are not seven commands you must manually run.

## Forge stages

| Stage | Meaning | Owner |
|---|---|---|
| 🔥 **Ignite** | preflight, GitHub auth, base/branch preparation | deterministic script + Codex |
| 🔎 **Inspect** | map relevant code, conventions, tests, risks | `pulmu_explorer` read-only subagent |
| 📐 **Shape** | choose forge mode and form the implementation plan | main Codex |
| 🔨 **Hammer** | implement the smallest complete change | main Codex (single writer) |
| 🌊 **Quench** | lint/typecheck/test/build and retry fixes when needed | deterministic script + main Codex |
| 🪨 **Hone** | independent correctness/regression/security/test review | `pulmu_reviewer` read-only subagent |
| 📦 **Ship** | commit, push, and create a GitHub PR | deterministic script + Codex |

### Status language

Pulmu uses a small, consistent terminal vocabulary:

```text
● active
✓ success
✗ failed
↻ retry
• sub-task
⚠ warning
```

## Forge modes

Every mode still goes through **all seven stages**. Only the depth changes.

- **Quick Forge** — small, low-risk, narrowly scoped changes.
- **Standard Forge** — normal features and bug fixes.
- **Full Forge** — migrations, auth/security, cross-cutting or breaking changes. Ships as a **draft PR** by default.

## Requirements

- Codex CLI with Skills support
- Git
- GitHub CLI (`gh`) authenticated (`gh auth status`)
- a Git repository with an `origin` remote
- the project's own runtime/toolchain for Quench (Node/Bun/Python/Rust/Go etc.)

Pulmu never force-pushes and never merges a PR.

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

Restart Codex if `$pulmu` does not appear immediately.

Then, from any GitHub-backed project:

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
│           ├── scripts/
│           │   ├── common.sh
│           │   ├── ignite.sh
│           │   ├── quench.sh
│           │   └── ship.sh
│           └── references/
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
- Full Forge produces a draft PR
- no merge
- no force push
- no destructive cleanup of unrelated user changes

## Development

Run Pulmu's local integration tests:

```bash
./tests/test.sh
```

The tests do not call a model. They verify shell syntax, demo tests, Quench discovery, installer layout, and a local `Ignite → branch → Quench → Ship` flow using a bare Git remote plus a fake `gh` command.

## License

MIT
