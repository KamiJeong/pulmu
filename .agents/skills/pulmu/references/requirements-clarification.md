# Clarifying incomplete requirements

Use when an unanswered requirement could materially change implementation or acceptance. The Orchestrator owns user questions; clarification is part of necessity assessment or the current stage, never an eighth stage or a separate required command.

## Decide whether to ask

Read the conversation, applicable repository instructions, and the relevant implementation/tests first. Reuse established behavior and prior answers. Check only dimensions that matter to this request: intended users and outcome, affected behavior and scope, data or permission rules, integration/compatibility constraints, and observable completion conditions. Do not ask the user to supply facts available in the repository or fill in a generic requirements template.

Distinguish three cases:

| Evidence | Action |
| --- | --- |
| The request or repository already supplies the answer | Proceed using that evidence; do not ask again. |
| An unspecified detail has a conventional, low-impact, reversible default within the authorized scope | State the assumption briefly when it matters and proceed. |
| An unresolved fact, conflict, or choice materially affects user-visible behavior, permissions/data handling, public contracts, cost, scope, or what counts as complete | Ask before implementing the dependent behavior. |

Examples: an established login flow with a specified redirect fix should not trigger a questionnaire about authentication providers. A new login feature with no established identity or signup policy may need a question about who can sign in and by what method. An unspecified internal helper name does not. A destructive data-cleanup request needs a defined retention/deletion boundary before deletion logic is implemented. These are examples of applying the decision rule, not questions to ask for every task.

## Ask the smallest useful question set

Usually ask the single question that unlocks the work; group up to three independent high-impact questions when useful. Explain briefly what each answer changes. Offer two or three understandable choices and a recommendation when evidence supports one; allow a free-text answer. Do not invent a recommended external fact or force a false choice when a factual answer is needed. Keep technical details limited to those needed for the decision.

For example, after confirming there is no existing signup policy:

> Who should be able to create an account: anyone, or invited users only? This determines whether public signup is included. For an internal employee tool, I recommend invited users only.

Use a supported question tool when appropriate and available; otherwise ask in a normal assistant response. A request to clarify behavior is not a routine approval request to start coding. A required answer remains pending until the user answers or explicitly delegates that decision; elapsed time, a preselected option, or no reply is not agreement. For an optional preference, a stated reversible default is enough to continue. Do not repeatedly ask the same question.

## Continue and consolidate

While awaiting a required answer, continue only useful independent read-only investigation, such as locating tests or tracing an existing API. Do not implement the unresolved behavior or spend work building competing implementations. Before Ignite, remain in necessity assessment without a branch, Run Context, or stage output. During an active run, retain the current stage and work; waiting for input alone is not a verification failure or a consumed retry.

When the user answers, fold the answer into a compact working brief with confirmed requirements, any consequential reversible assumptions, and observable acceptance conditions. This belongs in the existing Shape brief and relevant agent handoffs, not a mandatory new file or schema field. Include later clarifications in reviewer acceptance conditions without supplying writer reasoning or earlier verdicts.

If the user delegates a decision, choose within the stated constraints and proceed. Delegation does not supply missing external facts or resolve contradictory constraints; ask only for the facts or priority still needed. New questions are warranted only when new material evidence leaves another blocker. If an answer changes finalized scope or risk, use the existing `replan` transition and refresh affected verification/review evidence as described in `SKILL.md`; do not restart the run or silently keep the old plan.

Subagents return the exact unresolved fact or choice, its consequence, and any evidence to the Orchestrator. They do not independently negotiate requirements or fill a consequential gap with an invented policy. The designated writer pauses dependent edits until the Orchestrator supplies the resolution.
