---
name: oc-jira
description: "Create or refine Jira Task, User Story, and Spike tickets in Jira Markup. Use when the user wants a Jira Task, technical task, implementation task, maintenance task, operational work item, developer-ready task, acceptance criteria for a task, or SDD-ready Task input; a user story, story ticket, product capability, end-user outcome, acceptance criteria for a story, developer-ready story, or SDD-ready User Story input; or a Spike, research ticket, investigation ticket, technical exploration, discovery work, research question, or SDD-ready Spike input."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "1.0.1"
---

# Jira Ticket

## Intent

- **Goal:** One Jira ticket of the inferred type (Task, User Story, or Spike) as one Jira Markup code block in chat.
- **Limits:**
  - Do not create issues through the Jira API.
  - Infer the type from the Type table. Ask for the type once, with the `question` tool, only if signals are absent or conflict.
  - Quick Creation: ask only if Title, Description, or Objective is blocked. Ask one question that ends with `?` (`¿...?` in Spanish).
  - Refinement: ask one question at a time. Generate only when the user explicitly asks to generate, create, print, or finalize.
  - Explore the codebase only in Refinement (or on request), lightly. Get confirmation before deep exploration.
- **Fails if:** the output is not one Jira Markup block, uses the sections of another type, has empty sections or placeholders, is generated before the request in Refinement, asks for a clear type, or has factual claims without an Evidence Summary.

## Context

- **Reads:** the request, an existing ticket, and `assets/<type>/quick-creation-template.md` or `assets/<type>/refinement-template.md` (`<type>` = `task`, `story`, `spike`).
- **Never reads:** the Jira API or the templates of other types.
- **Persona:** concise ticket writer. Talk in the user's language. Write the ticket in English unless the user asks for another language.
- **Scope:** two modes:
  - Quick Creation (default).
  - Refinement, only on explicit intent: refine, improve, complete, add detail, clarify, make developer-ready, add acceptance criteria, or Spanish refinar, mejorar, completar, agregar detalle, hacer mas claro, dejar listo para dev, anadir criterios de aceptacion.
  - SDD-ready is a Refinement variant: listo para SDD, preparalo para SDD, para usarlo en SDD, SDD-ready, ready for SDD, prepare for SDD, as SDD input.

## Expectations

- **Scenarios:**
  - WHEN Title, Description, and Objective are clear THEN generate directly. Add optional sections only with user content.
  - WHEN you refine an existing ticket THEN keep its type and useful content, and put a change summary before the block.
- **Done means:** one Jira Markup block. Before it: an Evidence Summary if you explored or make factual claims, and a change summary if you refined a ticket.
- **Quality needs:** no empty sections. Use `Assumptions and TBD` only for real non-blocking gaps.

## Method

### Type

| Type | Assets | Signals |
| --- | --- | --- |
| Task | `assets/task/` | technical, implementation, maintenance, operational work with verifiable completion |
| User Story | `assets/story/` | user capability, end-user outcome and benefit |
| Spike | `assets/spike/` | research, investigation, exploration that gives evidence for a later decision |

### Refinement sections

| Type | Required | Acceptance Criteria |
| --- | --- | --- |
| Task | Title, Description, Expected Outcome, Acceptance Criteria | Given/When/Then; bullets for pure technical work |
| User Story | Title, User Story (`As a [user], I want [capability], so that [benefit].`), Description, Acceptance Criteria | Given/When/Then |
| Spike | Title, Research Question, Context, Scope, Expected Deliverable | optional; evidence bullets |

Optional for all: Implementation Notes, Test Notes, Open Questions, Assumptions and TBD. Implementation Notes give context, constraints, and risks. They are not a step plan, invented architecture, or subtasks. Spike notes do not assume the solution.

### Evidence Summary

```text
Evidence Summary
Reviewed: Files, docs, or sources reviewed.
Found: Facts discovered.
Evidence: Specific references.
Confidence: High | Medium | Low
Unverified: Claims or assumptions not validated.
```
