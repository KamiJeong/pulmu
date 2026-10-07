# Pulmu agent-orchestration contract

The main Codex session is the **Orchestrator**. It owns `update_plan`, Forge depth, execution-path selection, stage transitions, routing, evidence consolidation, retry decisions, and delivery. It may be the designated task-file writer on any execution path.

Each run has exactly one designated writer: the Orchestrator or `pulmu_smith`. Every Scout, Architect, Designer, Analyst, and Reviewer other than Smith is read-only. Never run multiple writers in the shared working tree. If metadata selects Smith and that role is unavailable, stop Hammer rather than silently switching writers.

## Agent inventory

| Agent | Stage | Model | Effort | Sandbox | Responsibility |
|---|---|---|---|---|---|
| `pulmu_explorer` | Inspect | `gpt-6-luna` | medium | read-only | repository structure, relevant code, conventions, dependencies, impacted files |
| `pulmu_test_scout` | Inspect | `gpt-6-luna` | medium | read-only | tests, test conventions, lint/typecheck/build commands, validation strategy |
| `pulmu_risk_scout` | Inspect | `gpt-6.1-sol` | high | read-only | compatibility, auth, migration, data loss, dependency, concurrency, breaking risk |
| `pulmu_architect` | Shape | `gpt-6.1-sol` | high | read-only | boundaries, modules, data flow, sequencing, compatibility, technical risk |
| `pulmu_designer` | Pattern | `gpt-6.1-sol` | medium | read-only | existing design language, hierarchy, states, responsive behavior, accessibility |
| `pulmu_smith` | Hammer | `gpt-6.1-sol` | medium | workspace-write | implementation, tests, and necessary task-file changes |
| `pulmu_failure_analyst` | Quench failure | `gpt-6.1-sol` | high | read-only | root cause, cascading failures, unrelated failures, likely affected code |
| `pulmu_reviewer` | Hone | `gpt-6.1-sol` | high | read-only | correctness and regression |
| `pulmu_test_reviewer` | Hone | `gpt-6.1-sol` | medium | read-only | missing tests, weak assertions, validation gaps |
| `pulmu_security_reviewer` | Hone | `gpt-6.1-sol` | high | read-only | authentication, authorization, sensitive data, security-sensitive code |
| `pulmu_compat_reviewer` | Hone | `gpt-6.1-sol` | high | read-only | public APIs, schemas, migrations, external integrations, compatibility |
| `pulmu_design_reviewer` | Hone | `gpt-6.1-sol` | medium | read-only | Pattern intent, consistency, responsive states, accessibility, visual restraint |

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
- The Orchestrator gives each agent a self-contained brief: the original task with accepted clarifications and acceptance conditions, stated assumptions, repository/instruction paths, base/current branch, assigned files or boundary, relevant evidence, and one unresolved investigation question. Include the writer designation for implementation. Reviewers instead receive only the fresh, candidate-scoped input defined in `review-contract.md`.
- Only the Orchestrator asks the user about requirements. Agents report material gaps and their consequences to it; unresolved product decisions are not delegated as implementation tasks. Follow `requirements-clarification.md` when such a gap remains after checking available evidence.
- The Orchestrator consolidates results; raw subagent output does not become extra `update_plan` items.
- Inspect and Shape determine type, forge, risk, areas, Pattern, execution path, writer, review mode, and specialist flags. The Orchestrator finalizes that canonical metadata once after Shape; reviewers and Ship consume it instead of re-inferring it.
- Architect and Designer return briefs, not edits. The Orchestrator renders disposable previews and asks unresolved product questions. Reuse an accepted or delegated direction; do not spawn Designer merely to repeat a comparison.
- The designated writer receives the original task, repository instructions, Inspect summary, architecture brief, and optional Pattern brief.
- When Smith is designated, reuse the same Smith through Hammer → Quench retry and Hone → Hammer refinements. When the Orchestrator is designated, it remains the only writer through retries.
- Failure Analyst is conditional: deterministic verification comes first, and straightforward failures go directly back to the designated writer.
- Reviewers never edit. The Orchestrator deduplicates findings, resolves conflicting severity with evidence, and sends blocking or accepted corrections to the designated writer.
- A required agent crash or malformed output gets one bounded transport/output repair request. If its required evidence still cannot be obtained, stop the current stage; never infer a PASS. Reviewer attempts follow the stricter receipt procedure in `review-contract.md`.
- If implementation or review reveals a new security, compatibility, Pattern, or scope requirement outside finalized Shape decisions, call the explicit Run Context `replan` transition. It preserves task files, branch, run ID, and retries while invalidating finalized routing and downstream evidence; do not silently under-route reviewers or mutate metadata files by hand.
- Ignite, Quench verification, and Ship use no subagent unless the Quench failure-analysis condition applies.

## Reasoning configuration

Use the configured defaults rather than maximizing effort. Luna 6 at medium collects bounded repository and test evidence. Sol 6.1 at medium handles implementation, design, test review, and design review. Sol 6.1 at high handles architecture, risk, non-trivial failure analysis, correctness, security, and compatibility review. A cheaper model does not by itself mean fewer tokens, and these defaults are not a measured speed or quality guarantee.

The main Orchestrator retains the user's selected model and effort. Do not change user-wide configuration or add a global subagent-model default: each bundled role pins its own model and effort. Verify availability through the active runtime model list or a current local model catalog; do not guess model IDs. Required unavailable reviewers still block the stage. Optional unavailable scouts can be handled directly by the Orchestrator with the limitation disclosed.

If a Luna scout identifies ambiguity or a cross-cutting invariant it cannot resolve, use its paths and precise unknowns to reason in the Orchestrator or route one focused question to the Architect/Risk Scout. Do not repeat the whole repository scan. Straightforward verification errors go to the designated writer; reserve Failure Analyst for unresolved root causes. A failed check is not by itself a reason to maximize model effort.

The agent TOMLs are authoritative for each role's model and reasoning effort. Do not attempt spawn-time effort overrides or use `max` effort in the default Pulmu workflow.

## Context and tool economy

- Start delegated work without conversation history: explicitly use `fork_turns="none"` when supported, or the runtime's equivalent fresh-context control. Do not assume the default is fresh. If a runtime cannot isolate reviewer input, do not claim independent review.
- Pass file paths, symbols, candidate identities, and exact questions. Let agents read relevant content on demand rather than copying whole files or raw logs. Include applicable repository instructions; scope reduction must not remove acceptance conditions or constraints.
- Target about 300 words for scout results and 600 for architecture/design briefs. These are compression targets, not hard cutoffs: preserve material risks, unknowns, and all review findings. Evidence and limitations are more useful than a narrative of tool calls.
- Accept usable scout evidence and inspect cited code when needed to implement or resolve a conflict. Do not duplicate the entire scout search in the main context. Never reuse old findings as a fresh review verdict.
- Agents do not spawn agents or invoke the Pulmu workflow. Only the Orchestrator delegates, so nested fan-out cannot quietly multiply work or create writers.
- Run independent read-only questions concurrently when useful. Await completion notifications while doing other work; avoid repeated status polling. Capacity is a ceiling, not a target team size. Release finished threads where supported before starting fresh reviewers.
- Execute deterministic Git and verification helpers directly. Read a failing log excerpt before loading a full log; do not rerun a passing check merely to restate its result.

## Full-stack routing examples

| Task evidence | Useful delegation | Keep direct |
| --- | --- | --- |
| Small known UI or backend fix, low risk | none unless an independent question remains | inspection, implementation, required Pattern, explicit self-review |
| UI + API feature in an unfamiliar repository | Luna Explorer maps the request/data path; Luna Test Scout finds relevant checks; run in parallel only for separate questions | consolidate once; one writer; Sol correctness review and only required specialist/test/design reviews |
| Auth or schema migration | Sol Risk Scout or Architect for an unresolved invariant; Sol security/compatibility review when flagged | routine searches, verification and Git helpers; never replace specialist assurance with Luna |
| Failing integration check | Sol Failure Analyst only after the error remains non-trivial | exact reproduction and obvious fixes by the designated writer |

For measured policy comparisons, read [efficiency-evaluation.md](efficiency-evaluation.md). It is an optional maintainer evaluation procedure, not an extra stage or a prerequisite for ordinary runs.

## Delivery boundary

Ship has no subagent. The Orchestrator generates delivery metadata from the final diff and deterministic evidence, then the script stages only its expected-path manifest. For local delivery, a reviewed local commit completes Ship. For GitHub delivery, Ship completes only after commit, normal push, and a real pull-request URL; missing labels are non-blocking and reported. Never merge or force-push.
