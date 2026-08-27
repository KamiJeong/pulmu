# Pattern design-pass contract

`🎨 Pattern — Designing the experience` is a conditional design pass inside `📐 Shape`. It is not a top-level forge stage, never appears in the seven-item `update_plan` list, and does not edit source code. Read-only `pulmu_designer` produces the brief, the Orchestrator consolidates it, and Smith implements it during Hammer.

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

### Information hierarchy

Decide what users should see first, primary and secondary actions, content grouping, visual priority, whitespace, and density.

### Interaction states

Cover the states the feature actually needs: default, hover, focus, active, disabled, loading, empty, error, and success. Do not invent states irrelevant to the task.

### Responsive behavior

For UI work, define behavior for desktop, tablet, mobile, and narrow viewports. Preserve a natural information structure and interaction model rather than merely shrinking the desktop layout.

### Accessibility

Define semantic markup, keyboard interaction, visible focus, labels, contrast, and ARIA only where native semantics are insufficient.

### Visual restraint

Prefer consistency with the existing product. Unless requested or already established, avoid unnecessary gradients, excessive cards or shadows, overly rounded surfaces, decorative icon overload, and animation without a functional purpose.

## Pattern brief

Before Hammer, Designer returns and the Orchestrator records only the decisions needed for Smith implementation and Design Reviewer verification:

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
