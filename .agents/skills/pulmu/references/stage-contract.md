# Pulmu stage contract

Pulmu is one skill and one public command. The seven stage names form its stable user-facing workflow vocabulary.

## Stage order

1. 🔥 Ignite
2. 🔎 Inspect
3. 📐 Shape
4. 🔨 Hammer
5. 🌊 Quench
6. 🪨 Hone
7. 📦 Ship

Do not reorder these stages in the normal workflow.

## Terminal contract

At stage start:

```text
🔥 Ignite   Preparing the forge...
🔎 Inspect  Exploring the repository...
📐 Shape    Forming the implementation plan...
🔨 Hammer   Implementing...
🌊 Quench   Running verification...
🪨 Hone     Reviewing and refining...
📦 Ship     Creating the pull request...
```

Stage details should use only the small status vocabulary:

- `●` active
- `✓` successful check/result
- `✗` failure
- `↻` retry/refinement loop
- `•` subordinate work item
- `⚠` non-blocking warning

Avoid turning the terminal into a dashboard full of decorations. The forge metaphor should make state clearer, not noisier.

## Retry paths

```text
Hammer → Quench ──fail──→ Hammer → Quench
Quench → Hone ─finding─→ Hammer → Quench → Hone
```

Ship only follows a passing Quench and non-blocking Hone.
