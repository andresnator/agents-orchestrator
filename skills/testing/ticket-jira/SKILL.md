---
name: ticket-jira
description: |
  Create Jira tickets through a structured interview for User Story, Task, or Spike outputs. Use when the user wants a Jira ticket, Jira task, user story, spike, acceptance criteria, criterios de aceptación, historia de usuario, tarea de Jira, or crear ticket de Jira.
license: MIT
metadata:
  author: andresnator
  version: "1.0.1"
---

# Jira Ticket Interview

## Activation Contract

Use this skill to help create a Jira ticket through an interview. The final artifact is printed in chat/console only; do not save a `.md` file unless the user explicitly asks.

Always load the template matching the selected ticket type before generating:

- `assets/user-story-template.md`
- `assets/task-template.md`
- `assets/spike-template.md`

## Hard Rules

- Always ask for ticket type first. Do not infer it.
- Offer exactly these ticket types: User Story, Task, Spike.
- Ask one question at a time and wait for user feedback.
- Keep asking until the user explicitly asks to generate, such as `generate ticket`, `generá el ticket`, `crear ticket`, `imprimir ticket`, `listo, generá`, or an equivalent phrase. Do not treat standalone casual words like `listo` or `pará` as generation triggers when ambiguous.
- If the user explicitly asks to stop or cancel, such as `stop`, `cancel`, `pará`, `dejalo`, `forget it`, or an equivalent phrase, confirm the interview is stopped and do not generate a ticket.
- Follow the user's language during the interview.
- Generate the final Jira ticket in English by default unless the user explicitly requests another artifact language.
- Before generating, show a brief collected-context summary and ask whether to generate or adjust.
- If required sections cannot be completed from gathered context, ask for the missing required information before generating.
- Do not use placeholders, assumptions, or TBD for required fields.
- Put the final ticket in a single code block using Jira Markup, not generic Markdown.
- Capture missing non-blocking information as `Assumptions and TBD`; omit that section when there are no unresolved gaps.
- Omit optional sections entirely when empty.
- Do not perform implementation planning, sub-task decomposition, or detailed technical design.
- Dev Notes may capture constraints, dependencies, risks, or known technical context only; they must not become a build plan.

## Question Format

Every interview question must use this exact structure, adapted to Jira tickets:

```markdown
### Question N — [focused Jira ticket question]

**Why this matters:** [why this decision affects the Jira ticket]

**Estimated remaining questions in this interview:** ~M

**Recommended answer:** [short recommended/default answer when useful]
```

Keep `N` sequential across the whole interview. Keep `M` adaptive across the remaining interview.

## Execution Steps

1. Ask the ticket type first: User Story, Task, or Spike.
2. Read the matching template from `assets/`.
3. Gather only the context needed to complete required sections and any useful optional sections.
4. For User Story and Task acceptance criteria, use Given/When/Then.
5. For Spike acceptance criteria, use simple bullets by default; Given/When/Then is allowed only when it fits naturally.
6. If the user explicitly asks to stop or cancel, stop the interview without generating.
7. When the user explicitly asks to generate, summarize collected context and ask whether to generate or adjust.
8. Generate one Jira Markup code block using the selected template.

## Required Sections

| Type | Required | Optional |
| --- | --- | --- |
| User Story | Title, User Story, Description, Acceptance Criteria | Dev Notes, Test Notes, Assumptions and TBD |
| Task | Title, Description, Expected Outcome, Acceptance Criteria | Dev Notes, Test Notes, Assumptions and TBD |
| Spike | Title, Research Question, Context, Scope, Expected Deliverable | Acceptance Criteria, Dev Notes, Test Notes, Assumptions and TBD |

## References

- `assets/user-story-template.md` — Jira Markup template for User Story tickets.
- `assets/task-template.md` — Jira Markup template for Task tickets.
- `assets/spike-template.md` — Jira Markup template for Spike tickets.
