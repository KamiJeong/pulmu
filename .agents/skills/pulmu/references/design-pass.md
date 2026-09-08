# Pattern design-pass contract

`🎨 Pattern — Designing the experience` is a conditional design pass inside `📐 Shape`. It is not a top-level forge stage and never appears in the seven-item `update_plan` list. The Orchestrator may produce the brief directly; use read-only `pulmu_designer` only when a separate design context adds value. The designated writer implements the brief during Hammer.

## When Pattern runs

Run Pattern when Inspect finds meaningful user-facing design impact, including:

- UI additions or changes, new screens or pages
- dashboards, forms, navigation, or component composition
- user interactions or default/hover/focus/active/disabled states
- loading, empty, error, or success states
- responsive layouts, mobile behavior, or narrow-view component behavior
- visual hierarchy or other frontend changes that affect the user experience

Skip Pattern for backend-only or API-only changes, infrastructure, CI/CD, test-only work, internal refactors, and bug fixes with no meaningful visible behavior. Decide from Inspect evidence rather than keywords alone.

## Design decisions

### Existing design language

Inspect and reuse the repository's components, design tokens, typography, spacing, color usage, layout and icon conventions, interaction patterns, Storybook or design system, and Tailwind/CSS/UI framework conventions. Do not introduce a new visual language without a clear product reason.

When no coherent product-level visual and experience direction exists, read [design-selection.md](design-selection.md). Existing Tailwind, component-library, or token foundations may still be reused. Recommend a product-appropriate direction instead of asking the user to invent design terminology. Offer two same-content representative choices only when the direction is consequential.

### Information hierarchy

Decide what users should see first, primary and secondary actions, content grouping, visual priority, whitespace, and density.

### Interaction states

Cover the states the feature actually needs: default, hover, focus, active, disabled, loading, empty, error, and success. Do not invent states irrelevant to the task.

### Responsive behavior

For UI work, define behavior at the product's supported targets and the constraining widths relevant to the changed layout. Preserve a natural information structure and interaction model rather than merely shrinking a wide layout.

### Accessibility

Define semantic markup, keyboard interaction, visible focus, labels, contrast, and ARIA only where native semantics are insufficient.

### Visual restraint

Prefer consistency with the existing product. Unless requested or already established, avoid unnecessary gradients, excessive cards or shadows, overly rounded surfaces, decorative icon overload, and animation without a functional purpose.

## Pattern brief

Before Hammer, the Pattern owner returns and the Orchestrator records only the decisions needed for implementation and applicable review:

- reused design-language primitives
- hierarchy and primary/secondary actions
- required interaction and content states
- responsive behavior
- accessibility requirements
- explicit restraint or non-goals

Keep the brief proportional to the task. In progress messages, Pattern may appear only as a subordinate Shape activity:

```text
🎨 Pattern — Designing the experience
  ● Defining hierarchy, interaction, responsive behavior, and accessibility
```

After completion, Shape may summarize the result in one line:

```text
✓ 🎨 Pattern — responsive layout and interaction states defined
```

Review actual rendered behavior in proportion to the change. A static mock can support a direction decision, but it does not prove responsive layout, keyboard/focus behavior, semantics, contrast, or functioning interactions.
