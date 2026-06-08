---
name: prd-light
description: >
  Create lightweight Product Requirements Documents for MVPs, internal tools, small or medium
  features, and early ideas that need alignment without ceremony. Trigger on "PRD light",
  "quick PRD", "lightweight PRD", "simple PRD", "mini PRD", "short PRD", "brief PRD",
  "MVP requirements", "internal requirements", "quick requirements", or "rough PRD".
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
---

# PRD Light

## Activation Contract

Use this skill to create a useful, lightweight PRD quickly. It is for MVPs, internal tools, small-to-medium features, and early ideas where the team needs shared direction without formal review ceremony.

Always read `references/prd-light-template.md` at the start of the session and use it as the final document skeleton.

## Hard Rules

- Keep the conversation brief and practical.
- Work one phase at a time.
- Ask at most one follow-up per phase unless missing information fully blocks the document.
- Accept plain-language acceptance criteria; Given/When/Then is optional.
- Skip non-relevant details easily; use `N/A` without heavy justification.
- Produce a useful draft fast instead of chasing perfect completeness.
- Do not invent unknowns; use open questions or assumptions when needed.
- Use the reference template for the final artifact.
- Ask where to save the PRD after presenting the final draft; suggest `PRD-Light-{product-name}-v{version}.md` if the user wants a default.

## Question Format

Every interview question must use this exact structure:

```markdown
### Question N — [focused PRD Light question]

**Why this matters:** [why this decision affects the PRD Light]

**Estimated remaining questions in this phase:** ~M

**Recommended answer:** [short recommended/default answer when useful]
```

Keep N sequential across the whole interview. Keep M adaptive within the current phase.

## Decision Gates

| Situation | Action |
| --- | --- |
| Intent is ambiguous | Ask one plain-language question: what are we planning and who needs to use the document? |
| Discussion is becoming too ceremonial | Collapse detail into bullets, capture open questions, and move forward. |
| Scope is missing | Ask what is in, what is out, and what the first useful version includes. |
| Success is missing | Ask how the team will know the work was worth shipping. |
| Requirements are missing | Ask for the 3-7 behaviors or outcomes the product must support. |
| Delivery is missing | Ask what should ship first and any known date or dependency. |
| Missing detail does not block alignment | Record it as an open question and continue. |

## Execution Steps

1. Read `references/prd-light-template.md`.
2. Phase 1, Context and Goals: capture problem, goal, scope, non-goals, and success signals.
3. Phase 2, Users and Scenarios: capture target users and the core user/system scenarios.
4. Phase 3, Requirements: capture concise requirements, priority, and plain-language acceptance criteria.
5. Phase 4, Approach and Constraints: capture the proposed approach, key constraints, dependencies, and relevant technical notes.
6. Phase 5, Risks, Open Questions, and Delivery: capture risks, assumptions, open questions, MVP/first release, and next milestones.
7. Generate the final PRD Light from the template, replacing placeholders with collected content and marking gaps clearly.
8. Present the final draft for review and ask where to save it.

## Validation Rules

- The problem and intended outcome are understandable in plain language.
- Scope includes the first useful version and at least one boundary.
- Success criteria are observable, even if lightweight.
- Requirements are concrete enough for a builder to start.
- Must-have requirements have acceptance criteria.
- Each must-have requirement connects to a goal or scenario.
- Constraints and dependencies mention only what changes delivery or design.
- Risks and open questions are visible.
- The delivery section identifies the MVP or first useful release.

## Output Contract

Return a concise PRD Light document in Markdown using `references/prd-light-template.md`.

After the draft, include a brief final review request covering:

- Anything still marked `TBD` or open.
- Whether the MVP/first release feels correct.
- Suggested save path or a question asking where to save the file.

## References

- `references/prd-light-template.md` — lightweight PRD template.
