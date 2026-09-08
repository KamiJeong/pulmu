# Design direction when the repository has no system

Use this reference only when Pattern is required and repository inspection finds no coherent product-level visual and experience direction. An installed component library, Tailwind setup, or reusable primitives may remain the implementation foundation without answering that product-level question.

## Make the product decision first

Infer the product type, primary users, repeated tasks, information density, platform, brand constraints, and implementation stack from the request and repository. Do not ask the user to select isolated colors, spacing values, or component names. Recommend a coherent direction in terms they can judge, such as “dense repeated operations” or “guided first-time completion.”

For a small or reversible UI addition, state one suitable direction and proceed. When the choice would materially affect several screens, navigation, brand expression, or implementation cost, provide two distinct, viewable representative artifacts using the same screen, content, and core action. Prefer a rendered lightweight prototype; label a static mock clearly when interaction is not implemented. Recommend one and explain:

- why it fits the product and users;
- the visible layout, density, hierarchy, and interaction difference;
- the implementation and dependency tradeoff;
- whether it reuses repository code or introduces a new foundation.

Wait only when the choice is consequential and the user has not already chosen or delegated the decision.
If the available tools cannot produce a viewable comparison, disclose that limit and ask for direction instead of presenting prose as if it were a visual comparison. When the user delegated the choice, select the recommendation and proceed.

## Shortlist named design references

Use the named systems and guidelines below as starting candidates. Shortlist by product needs and repository constraints; this is not a popularity ranking or a list of interchangeable implementation libraries.

Classify a shortlisted reference before presenting it:

| Kind | Typical examples | What it can justify |
| --- | --- | --- |
| platform guidance | Apple Human Interface Guidelines | platform conventions and interaction guidance |
| general product UI system | Google Material Design, Microsoft Fluent, IBM Carbon, Adobe Spectrum | component behavior, tokens, composition, and implementation candidates |
| ecosystem-specific system | Shopify Polaris, Salesforce Lightning Design System, SAP Fiori | fit within the corresponding product ecosystem |
| brand/editorial reference | Audi, Guardian, Mailchimp | visual voice, typography, and content hierarchy inspiration |

Do not imply that a guideline, brand case study, or Figma asset provides production components. Do not adopt another company's brand identity wholesale.

After narrowing to one or two candidates, verify current primary sources for implementation support, framework compatibility, maintenance status, and license before recommending adoption. Report only what was verified for the current task. If a current primary source cannot be checked, use the candidate as visual guidance only and disclose that limitation.

## Produce an implementable brief

Record only the rules the task needs:

- information hierarchy and primary/secondary actions;
- typography, spacing, color roles, surfaces, and icon approach;
- reused or required components;
- loading, empty, error, disabled, validation, success, and permission states that apply;
- responsive rearrangement and interaction behavior;
- semantics, labels, keyboard path, focus, contrast, and motion constraints.

A static mock or generated image can validate direction and composition. It cannot prove responsive behavior, keyboard access, focus behavior, semantics, contrast, or working interaction. Verify those claims on the rendered implementation with suitable browser and accessibility checks, and state any checks that could not be performed.

When the user gives subjective feedback such as “cramped,” “dated,” or “empty,” translate it into a small testable hypothesis about hierarchy, density, typography, color, or spacing. Show the revised representative result rather than demanding design vocabulary from the user.
