---
name: oc-prd-light
description: "Trigger: PRD light, quick PRD, lightweight PRD, MVP requirements. Create lightweight PRDs for small features, internal tools, and early ideas."
license: MIT
metadata:
  author: andresnator
  status: done
  version: "3.1.0"
---

# PRD Light

## Intent

- **Goal:** A useful lightweight PRD, produced quickly and filled into `assets/prd-light-template.md`.
- **Limits:**
  - Keep the conversation brief and practical; one phase at a time, at most one follow-up per phase unless missing information fully blocks the document.
  - Ask open-ended questions in normal chat; use the `question` tool only for a closed confirmation or enumerated choice. No question headings, numbering, rationale blocks, or interview-length estimates.
  - Accept plain-language acceptance criteria (Given/When/Then optional); allow `N/A` without heavy justification.
  - Do not invent unknowns; use open questions or assumptions.
- **Fails if:** must-have requirements lack acceptance criteria, risks or open questions are hidden, the MVP is not identified, or the conversation turns into formal review ceremony instead of a fast draft.

## Context

- **Reads:** `assets/prd-light-template.md` (always, at session start; it is the final skeleton).
- **Never reads:** none.
- **Persona:** pragmatic product partner favoring a useful draft over perfect completeness.
- **Scope:** MVPs, internal tools, small-to-medium features, and early ideas needing shared direction without formal review.

## Expectations

- **Scenarios:**
  - WHEN the user asks for a light PRD THEN run the five phases and produce the draft.
  - WHEN a missing detail does not block alignment THEN record it as an open question and continue.
- **Done means:** a concise PRD Light in Markdown using `assets/prd-light-template.md`, followed by a brief review request covering anything still `TBD` or open, whether the MVP/first release feels correct, and a save-path question (default suggestion `PRD-Light-{product-name}-v{version}.md`).
- **Quality needs:**
  - Problem and outcome are understandable in plain language; scope includes the first useful version and at least one boundary.
  - Success criteria are observable; requirements are concrete enough to start building and each must-have connects to a goal or scenario.
  - Constraints and dependencies mention only what changes delivery or design.

## Method

### Question format

```markdown
[Direct question]

Recommendation: [short recommended/default answer when useful]
```

Omit the recommendation line when it adds no value.

### Decision gates

| Situation | Action |
| --- | --- |
| Intent is ambiguous | Ask one plain-language question: what are we planning and who needs to use the document? |
| Discussion is becoming too ceremonial | Collapse detail into bullets, capture open questions, and move forward. |
| Scope is missing | Ask what is in, what is out, and what the first useful version includes. |
| Success is missing | Ask how the team will know the work was worth shipping. |
| Requirements are missing | Ask for the 3-7 behaviors or outcomes the product must support. |
| Delivery is missing | Ask what should ship first and any known date or dependency. |

### Phases

1. Context and Goals: problem, goal, scope, non-goals, success signals.
2. Users and Scenarios: target users, core user/system scenarios.
3. Requirements: concise requirements, priority, plain-language acceptance criteria.
4. Approach and Constraints: proposed approach, key constraints, dependencies, relevant technical notes.
5. Risks, Open Questions, and Delivery: risks, assumptions, open questions, MVP/first release, next milestones.

Then generate the draft from the template, replacing placeholders and marking gaps clearly.

### Resources

- `assets/prd-light-template.md` — lightweight PRD template.
