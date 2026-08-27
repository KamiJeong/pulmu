# Pulmu agent-orchestration contract

The main Codex session is the **Orchestrator**. It owns `update_plan`, Forge Mode selection, stage transitions, subagent routing, evidence consolidation, retry decisions, and delivery. It does not edit application/source/test files.

`pulmu_smith` is the sole task-file writer. Every Scout, Architect, Designer, Analyst, and Reviewer is read-only. Never run multiple writers in the shared working tree. If Smith is unavailable, stop Hammer and explain how to install or reload the role instead of silently choosing another writer.

## Agent inventory

| Agent | Stage | Model | Effort | Sandbox | Responsibility |
|---|---|---|---|---|---|
| `pulmu_explorer` | Inspect | `gpt-5.6-terra` | medium | read-only | repository structure, relevant code, conventions, dependencies, impacted files |
| `pulmu_test_scout` | Inspect | `gpt-5.6-luna` | medium | read-only | tests, test conventions, lint/typecheck/build commands, validation strategy |
| `pulmu_risk_scout` | Inspect | `gpt-5.6-terra` | high | read-only | compatibility, auth, migration, data loss, dependency, concurrency, breaking risk |
| `pulmu_architect` | Shape | `gpt-5.6-sol` | high | read-only | boundaries, modules, data flow, sequencing, compatibility, technical risk |
| `pulmu_designer` | Pattern | `gpt-5.6-sol` | high | read-only | existing design language, hierarchy, states, responsive behavior, accessibility |
| `pulmu_smith` | Hammer | `gpt-5.6-sol` | high | workspace-write | implementation, tests, and necessary task-file changes |
| `pulmu_failure_analyst` | Quench failure | `gpt-5.6-terra` | high | read-only | root cause, cascading failures, unrelated failures, likely affected code |
| `pulmu_reviewer` | Hone | `gpt-5.6-terra` | high | read-only | correctness and regression |
| `pulmu_test_reviewer` | Hone | `gpt-5.6-terra` | medium | read-only | missing tests, weak assertions, validation gaps |
| `pulmu_security_reviewer` | Hone | `gpt-5.6-sol` | high | read-only | authentication, authorization, sensitive data, security-sensitive code |
| `pulmu_compat_reviewer` | Hone | `gpt-5.6-terra` | high | read-only | public APIs, schemas, migrations, external integrations, compatibility |
| `pulmu_design_reviewer` | Hone | `gpt-5.6-sol` | medium | read-only | Pattern intent, consistency, responsive states, accessibility, visual restraint |

## Forge Mode matrix

| Mode | Inspect | Shape | Hammer | Hone |
|---|---|---|---|---|
| Quick | Explorer | Orchestrator; Designer only for Pattern | Smith | Reviewer; Design Reviewer when Pattern ran |
| Standard | Explorer + Test Scout | Architect; Designer only for Pattern | Smith | Reviewer + Test Reviewer; Design Reviewer when Pattern ran |
| Full | Explorer + Test Scout + Risk Scout | Architect; Designer only for Pattern | Smith | Reviewer + Test Reviewer; Security and Compatibility Reviewers when relevant; Design Reviewer when Pattern ran |

Choose a provisional mode during Ignite so Inspect routing is possible. Inspect evidence may escalate Quick → Standard → Full, but do not downgrade after mode-specific agents have run. An escalation may require running the newly applicable scouts before Shape completes.

## Routing and handoffs

- Parallelize only independent read-only work. Do not spawn agents merely to increase count.
- The Orchestrator gives each agent the original task, base/current branch, relevant prior evidence, and a narrow role-specific question.
- The Orchestrator consolidates results; raw subagent output does not become extra `update_plan` items.
- Inspect and Shape determine type, forge, risk, areas, Pattern, and conditional review flags. The Orchestrator finalizes that canonical metadata once after Shape; reviewers and Ship consume it instead of re-inferring it.
- Architect and Designer return briefs, not edits.
- Smith receives the original task, repository instructions, Inspect summary, architecture brief, and optional Pattern brief.
- Reuse the same Smith through Hammer → Quench retry and Hone → Hammer refinements.
- Failure Analyst is conditional: deterministic verification comes first, and straightforward failures go directly back to Smith.
- Reviewers never edit. The Orchestrator deduplicates findings, resolves conflicting severity with evidence, and sends only blocking or accepted corrections to Smith.
- Ignite, Quench verification, and Ship use no subagent unless the Quench failure-analysis condition applies.

## Reasoning escalation

Use the configured defaults rather than maximizing effort. Luna handles narrow repetitive inspection at medium. Terra handles exploration, analysis, and review at medium or high. Sol handles architecture, design, implementation, and critical review at high.

Only authentication, authorization, payment, destructive database migration, data-loss risk, cryptography, concurrency, or public API breaking changes may justify an `xhigh` spawn override. Apply that override only to Architect or Security Reviewer. Never use `max` effort in the default Pulmu workflow.

## Delivery boundary

Ship has no subagent. The Orchestrator generates delivery metadata from the final diff and deterministic evidence, then the script stages only its expected-path manifest. For local delivery, a reviewed local commit completes Ship. For GitHub delivery, Ship completes only after commit, normal push, and a real pull-request URL; missing labels are non-blocking and reported. Never merge or force-push.
