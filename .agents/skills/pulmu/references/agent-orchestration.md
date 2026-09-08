# Pulmu agent-orchestration contract

The main Codex session is the **Orchestrator**. It owns `update_plan`, Forge depth, execution-path selection, stage transitions, routing, evidence consolidation, retry decisions, and delivery. It may be the designated task-file writer on any execution path.

Each run has exactly one designated writer: the Orchestrator or `pulmu_smith`. Every Scout, Architect, Designer, Analyst, and Reviewer other than Smith is read-only. Never run multiple writers in the shared working tree. If metadata selects Smith and that role is unavailable, stop Hammer rather than silently switching writers.

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

## Adaptive routing

| Execution | Inspect / Shape | Hammer | Hone |
|---|---|---|---|
| `direct` | Orchestrator; no required agent | Orchestrator | explicit `pulmu_self_review` receipt |
| `reviewed` | Orchestrator; focused scouts/Designer optional | Orchestrator | fresh independent required reviewers |
| `delegated` | focused Scouts/Architect/Designer only when useful | designated Orchestrator or Smith | fresh independent required reviewers |

Quick, Standard, and Full express investigation and risk depth; they do not prescribe an agent count. Choose the final depth and execution path from evidence during Shape. A tiny Quick task can run without an agent. A risky or unfamiliar task may use several focused read-only roles.

## Routing and handoffs

- Parallelize only independent read-only work. Do not spawn agents merely to increase count.
- After consolidating a read-only scout/architect/designer result or recording a reviewer receipt, release that finished thread with the runtime's supported agent-lifecycle control. Keep the Smith thread available for bounded fixes, but start reviewers fresh for each Quench candidate. If required fresh review capacity is unavailable after cleanup, stop rather than omit the reviewer or reuse implementation context.
- The Orchestrator gives each agent the original task, base/current branch, relevant prior evidence, and a narrow role-specific question. Reviewers instead receive the fresh, candidate-scoped input defined in `review-contract.md`.
- The Orchestrator consolidates results; raw subagent output does not become extra `update_plan` items.
- Inspect and Shape determine type, forge, risk, areas, Pattern, execution path, writer, review mode, and specialist flags. The Orchestrator finalizes that canonical metadata once after Shape; reviewers and Ship consume it instead of re-inferring it.
- Architect and Designer return briefs, not edits.
- The designated writer receives the original task, repository instructions, Inspect summary, architecture brief, and optional Pattern brief.
- When Smith is designated, reuse the same Smith through Hammer → Quench retry and Hone → Hammer refinements. When the Orchestrator is designated, it remains the only writer through retries.
- Failure Analyst is conditional: deterministic verification comes first, and straightforward failures go directly back to the designated writer.
- Reviewers never edit. The Orchestrator deduplicates findings, resolves conflicting severity with evidence, and sends blocking or accepted corrections to the designated writer.
- A required agent crash or malformed output gets one bounded transport/output repair request. If its required evidence still cannot be obtained, stop the current stage; never infer a PASS. Reviewer attempts follow the stricter receipt procedure in `review-contract.md`.
- If implementation or review reveals a new security, compatibility, Pattern, or scope requirement outside finalized Shape decisions, call the explicit Run Context `replan` transition. It preserves task files, branch, run ID, and retries while invalidating finalized routing and downstream evidence; do not silently under-route reviewers or mutate metadata files by hand.
- Ignite, Quench verification, and Ship use no subagent unless the Quench failure-analysis condition applies.

## Reasoning configuration

Use the configured defaults rather than maximizing effort. Luna handles narrow repetitive inspection at medium. Terra handles exploration, analysis, and review at medium or high. Sol handles architecture, design, Smith implementation, and critical review at high.

The agent TOMLs are authoritative for each role's model and reasoning effort. Do not attempt spawn-time effort overrides or use `max` effort in the default Pulmu workflow.

## Delivery boundary

Ship has no subagent. The Orchestrator generates delivery metadata from the final diff and deterministic evidence, then the script stages only its expected-path manifest. For local delivery, a reviewed local commit completes Ship. For GitHub delivery, Ship completes only after commit, normal push, and a real pull-request URL; missing labels are non-blocking and reported. Never merge or force-push.
