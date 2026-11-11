---
name: oc-jira
description: "Create or refine Jira Task, User Story, and Spike tickets in Jira Markup. Use when the user wants a Jira Task, technical task, implementation task, maintenance task, operational work item, developer-ready task, acceptance criteria for a task, or SDD-ready Task input; a user story, story ticket, product capability, end-user outcome, acceptance criteria for a story, developer-ready story, or SDD-ready User Story input; or a Spike, research ticket, investigation ticket, technical exploration, discovery work, research question, or SDD-ready Spike input."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "1.0.0"
---

# Jira Ticket

## Intent

- **Goal:** Generate one Jira ticket of the inferred type (Task, User Story, or Spike) as one Jira Markup code block in chat.
- **Limits:**
  - Output Jira Markup in chat only; never create Jira issues through the Jira API.
  - Infer the ticket type from the request using the Type table. Ask for the type once, as a closed choice with the `question` tool, only when the signals are absent or point to more than one type; otherwise never ask for it, and never second-guess or suggest another type.
  - Quick Creation may ask only when missing information blocks Title, Description, or Objective, with one direct interrogative question ending with `?` (Spanish `¿...?` when the conversation is Spanish).
  - Refinement asks one question at a time, waits for the user, and does not generate until the user explicitly asks to generate, create, print, or finalize the ticket.
  - Ask open-ended questions directly in normal chat; add `Recommendation: ...` only when it helps. No question headings, numbering, rationale blocks, or interview-length estimates. Use the `question` tool only for a closed confirmation or enumerated choice.
  - Codebase exploration applies only to Refinement / SDD-ready when it can answer factual questions or validate assumptions (Quick Creation only when explicitly requested). It is light by default (search/read a few relevant files); deep exploration requires explicit confirmation.
- **Fails if:** the ticket is not a single Jira Markup code block, uses another type's template or sections, contains empty sections or placeholders, generates Refinement output before an explicit generation request, asks for the type when the signal was clear, or makes technical/factual claims without an Evidence Summary.

## Context

- **Reads:** the user's request, any existing ticket to refine, `assets/<type>/quick-creation-template.md` (Quick Creation) or `assets/<type>/refinement-template.md` (Refinement) where `<type>` is `task`, `story`, or `spike`, and a few relevant repository files when exploration is allowed.
- **Never reads:** the Jira API, other types' templates, or unrelated repository areas; no deep exploration without confirmation.
- **Persona:** concise Jira ticket writer who follows the user's language in conversation and writes the final ticket in English unless the user explicitly requests another artifact language.
- **Scope:** Task, User Story, and Spike tickets, in two modes:
  - Quick Creation (default).
  - Refinement, only when the user explicitly asks to refine, improve, complete, add detail, clarify, make developer-ready, add acceptance criteria, or equivalent Spanish intent such as refinar, mejorar, completar, agregar detalle, hacer mas claro, dejar listo para dev, or anadir criterios de aceptacion.
  - SDD-ready is a Refinement variant, not a third mode, for listo para SDD, preparalo para SDD, para usarlo en SDD, SDD-ready, ready for SDD, prepare for SDD, as SDD input, or equivalent phrasing.

## Expectations

- **Scenarios:**
  - WHEN the request names or clearly implies one type THEN use it without asking.
  - WHEN the type is missing or ambiguous THEN ask once which type (Task, User Story, Spike), then continue.
  - WHEN the user gives enough for Title, Description, and Objective THEN generate directly with a minimal lead-in; include Acceptance Criteria or Implementation Notes only if the user provided useful content for them.
  - WHEN one of those three cannot be inferred safely THEN ask only one blocking question.
  - WHEN refining an existing ticket THEN keep its type, preserve useful content, improve only missing or unclear parts, and put a brief change summary before the Jira block.
- **Done means:** one Jira Markup code block, preceded by an Evidence Summary when exploration happened or the output makes technical/factual claims, and by a change summary when refining an existing ticket.
- **Quality needs:** omit empty sections and placeholders; use `Assumptions and TBD` only for real unresolved non-blocking gaps.

## Method

### Type

| Type | Assets | Signals | Content |
| --- | --- | --- | --- |
| Task | `assets/task/` | Jira Task, technical task, implementation task, maintenance task, operational work item, developer-ready task, acceptance criteria for a task, SDD-ready Task input | bounded work with an expected outcome and verifiable completion criteria |
| User Story | `assets/story/` | user story, story ticket, product capability, end-user outcome, acceptance criteria for a story, developer-ready story, SDD-ready User Story input | a user capability and the benefit it provides |
| Spike | `assets/spike/` | Spike, research ticket, investigation ticket, technical exploration, discovery work, research question, SDD-ready Spike input | research that answers a question, explores uncertainty, and produces evidence for a later decision |

### Refinement

Load the type's `refinement-template.md` and ask one question at a time in this shape, omitting the recommendation line when it adds no value:

```markdown
[Direct interrogative question?]

Recommendation: [Short suggested answer when useful.]
```

- Open Questions are especially useful for SDD-ready output when unresolved decisions affect scope, design, or acceptance.

Task:

- Required sections: Title, Description, Expected Outcome, Acceptance Criteria.
- Optional sections: Implementation Notes, Test Notes, Open Questions, Assumptions and TBD.
- Acceptance Criteria use Given/When/Then by default; verifiable bullets are allowed for pure technical work when Given/When/Then would be artificial.
- Implementation Notes may include technical guidance, constraints, dependencies, risks, known technical context, or SDD inputs. They must not become a step-by-step implementation plan, invented architecture, or subtasks disguised as design.

User Story:

- Required sections: Title, User Story, Description, Acceptance Criteria.
- Optional sections: Implementation Notes, Test Notes, Open Questions, Assumptions and TBD.
- The User Story section uses this shape: `As a [user], I want [capability], so that [benefit].`
- Acceptance Criteria use Given/When/Then by default.
- Implementation Notes are conservative: only real technical context, constraints, dependencies, risks, or SDD inputs. Avoid premature implementation design, invented architecture, step-by-step plans, or subtasks disguised as design.

Spike:

- Required sections: Title, Research Question, Context, Scope, Expected Deliverable.
- Optional sections: Acceptance Criteria, Implementation Notes, Test Notes, Open Questions, Assumptions and TBD.
- Acceptance Criteria are evidence or deliverable bullets by default; use Given/When/Then only when it fits naturally.
- Implementation Notes stay investigatory: areas to inspect, constraints, known risks, dependencies, or SDD inputs. They must not assume the solution, prescribe architecture, list subtasks, or become a step-by-step build plan.

### Evidence Summary

When required, place this before the Jira block; omit it when no exploration happened and no technical or factual claims are made:

Evidence Summary
Reviewed: Files, docs, or sources reviewed.
Found: Facts discovered.
Evidence: Specific references.
Confidence: High | Medium | Low
Unverified: Claims or assumptions not validated.
