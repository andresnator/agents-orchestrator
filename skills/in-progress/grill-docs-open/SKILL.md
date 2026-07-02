---
name: grill-docs-open
description: "Trigger: grill docs open, visual grilling with docs, question tool wrapper. Route to grill-with-docs while preserving its open-ended interview flow."
license: MIT
metadata:
  author: Agents Orchestrator maintainers
  inspired_by: Matt Pocock
  source_url: https://github.com/mattpocock/skills
  version: "1.0.2"
---

## Activation Contract

Use this wrapper when the user wants the `grill-with-docs` flow presented through opencode's `question` tool as a visual prompt container.

## Hard Rules

- Load and follow `grill-with-docs`; this wrapper only changes question presentation.
- Use the `question` tool as a visual container, not as a behavior change.
- For open-ended interview questions, keep the base skill's semantics: include a neutral option such as `Answer in chat` and let the user type a custom answer.
- Only use discrete multiple-choice style options when the delegated `grill-with-docs` flow genuinely requires a bounded choice.
- Do not render option menus in plain Markdown.
- Ask one question at a time, then stop and wait for the user's answer.
- Keep all other behavior aligned with `grill-with-docs` and any delegated skills it uses.

## Execution Steps

1. Load `grill-with-docs`.
2. Run its flow unchanged except for user prompt presentation.
3. For each user-facing question, call the `question` tool instead of writing a Markdown option list, preserving open-ended answers unless the delegated flow requires a discrete choice.
4. After each `question` call, stop and wait.

## Output Contract

Return the delegated grilling question or conclusion from the active `grill-with-docs` flow.

## References

- `../grill-with-docs/SKILL.md`

## Attribution

This wrapper skill is inspired by Matt Pocock's skills at <https://github.com/mattpocock/skills> and adapts the flow for opencode `question` tool UX.
