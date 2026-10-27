---
name: oc-prd
description: "Trigger: PRD, product requirements, technical product spec, PRD light, quick PRD, lightweight PRD, MVP requirements. Create rigorous PRDs (mode=full) for high-stakes, cross-team, regulated, or security-sensitive work, or lightweight PRDs (mode=light) for small features, internal tools, and early ideas."
license: MIT
metadata:
  author: andresnator
  status: done
  version: "4.1.0"
---

# PRD

## Intent

- **Goal:** A PRD in the selected mode: `mode=full` builds a complete, traceable technical PRD through a phase-by-phase interview filled into `assets/prd-template.md`; `mode=light` produces a useful lightweight PRD quickly, filled into `assets/prd-light-template.md`.
- **Limits:**
  - Use the given `mode`. Without one, choose `light` for explicit light or quick requests, MVPs, early ideas, internal tools, or small-to-medium features, and `full` for explicit full or formal requests or high-stakes, cross-team, security-sensitive, compliance-heavy, API-heavy, regulated, or approval-heavy work. The bare word PRD (or product requirements) is not a depth signal; light signals win unless a full signal is present. When the request is missing or the choice is still ambiguous, ask one plain-language triage question, then continue in the answered mode with no further confirmation.
  - Ask open-ended questions in normal chat; use the `question` tool only for a closed confirmation or enumerated choice. No question headings, numbering, rationale blocks, or interview-length estimates.
  - Do not invent unknown facts; keep uncertainty as open questions, assumptions, or explicit `TBD`.
  - Full:
    - Work one phase at a time; never dump the template as a questionnaire. Ask one focused question at a time where possible.
    - Summarize accumulated decisions and open items only at phase boundaries, not after every question. Validate the current phase before advancing.
    - Allow `N/A` only with a short justification; push back when skipping would hide material risk.
    - Avoid decorative tables that add no decision value.
  - Light:
    - Keep the conversation brief and practical; one phase at a time, at most one follow-up per phase unless missing information fully blocks the document.
    - Accept plain-language acceptance criteria (Given/When/Then optional); allow `N/A` without heavy justification.
- **Fails if:**
  - Any mode: a must-have requirement lacks acceptance criteria, or risks, gaps, or open questions are hidden.
  - Full: traceability across problem, goals, requirements, acceptance criteria, metrics, risks, and delivery is broken, or vague or contradictory requirements pass unchallenged.
  - Light: the MVP is not identified, or the conversation turns into formal review ceremony instead of a fast draft.

## Context

- **Reads:** the mode's template, always at session start (it is the final skeleton): `assets/prd-template.md` (full) or `assets/prd-light-template.md` (light); an existing PRD when resuming.
- **Never reads:** the other mode's template.
- **Persona:** full: rigorous product/technical interviewer who challenges vague, unverifiable, or contradictory requirements with a concrete reason; light: pragmatic product partner favoring a useful draft over perfect completeness.
- **Scope:** full: work needing strong alignment, explicit tradeoffs, measurable outcomes, quality/security coverage, dependency mapping, risks, acceptance criteria, and goal-to-delivery traceability; light: MVPs, internal tools, small-to-medium features, and early ideas needing shared direction without formal review.

## Expectations

- **Scenarios:**
  - WHEN the user asks for a full PRD THEN interview phase by phase and produce the full document.
  - WHEN the user asks for a light PRD THEN run the five light phases and produce the draft.
  - WHEN resuming an existing PRD THEN ask for the path, read it, summarize complete/incomplete sections, and continue from the first incomplete phase.
  - WHEN (light) a missing detail does not block alignment THEN record it as an open question and continue.
- **Done means:**
  - Full: the complete PRD in Markdown using `assets/prd-template.md`, followed by a short review request covering confirmed sections, remaining `TBD`/assumptions/open questions, and a save-path question (default suggestion `PRD-{product-name}-v{version}.md`).
  - Light: a concise PRD Light in Markdown using `assets/prd-light-template.md`, followed by a brief review request covering anything still `TBD` or open, whether the MVP/first release feels correct, and a save-path question (default suggestion `PRD-Light-{product-name}-v{version}.md`).
- **Quality needs:**
  - Full:
    - The problem names affected users and current pain; scope has in- and out-of-scope boundaries.
    - Each goal has at least one measurable or explicitly `TBD` success signal; quality requirements use numbers where numbers matter.
    - Security and compliance match the data and user access model; external dependencies include impact and fallback or degradation behavior.
    - Risks connect to requirements, architecture, dependencies, delivery, or unknowns; delivery covers must-haves and known blockers; open questions are visible.
  - Light:
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

### Full decision gates

| Situation | Action |
| --- | --- |
| Missing intent or product area | Ask what product, feature, or decision the PRD should cover. |
| Problem is vague or solution-first | Ask who has the problem, what hurts today, and why now. |
| Acceptance criteria are missing | Stop advancement for functional requirements until each must-have has verifiable criteria. |
| Metrics are not measurable | Ask for target, baseline if known, measurement method, or mark the metric as `TBD` with an owner. |
| Security, compliance, data, or dependency section is marked `N/A` | Require a short justification and record it in the PRD. |
| User cannot answer a detail yet | Capture an open question with owner/due date if known; continue only if the missing detail does not block validation. |

### Full phases

Start with document metadata (product/feature name, version, author, date, status), then:

1. Overview: problem, context, scope, out-of-scope, stakeholders, assumptions.
2. Goals and Success: goals, non-goals, measurable metrics, how success is checked.
3. Users and Use Cases: user groups, core scenarios, edge/error paths, priorities.
4. Requirements and Acceptance: functional requirements, priorities, acceptance criteria.
5. Quality, Security, and Dependencies: non-functional, data/security/compliance, dependencies, integrations, fallbacks.
6. Architecture and Interfaces: architecture, data flow, API/interface contracts, ownership, only where relevant to build or review decisions.
7. Risks and Open Questions: risks, mitigations, assumptions, unresolved questions, owners, due dates.
8. Delivery and Traceability: MVP/release slices, milestones, rollout/rollback, trace requirements to goals and acceptance criteria.

Then generate the PRD from the template, replacing placeholders and marking justified gaps clearly.

### Light decision gates

| Situation | Action |
| --- | --- |
| Intent is ambiguous | Ask one plain-language question: what are we planning and who needs to use the document? |
| Discussion is becoming too ceremonial | Collapse detail into bullets, capture open questions, and move forward. |
| Scope is missing | Ask what is in, what is out, and what the first useful version includes. |
| Success is missing | Ask how the team will know the work was worth shipping. |
| Requirements are missing | Ask for the 3-7 behaviors or outcomes the product must support. |
| Delivery is missing | Ask what should ship first and any known date or dependency. |

### Light phases

1. Context and Goals: problem, goal, scope, non-goals, success signals.
2. Users and Scenarios: target users, core user/system scenarios.
3. Requirements: concise requirements, priority, plain-language acceptance criteria.
4. Approach and Constraints: proposed approach, key constraints, dependencies, relevant technical notes.
5. Risks, Open Questions, and Delivery: risks, assumptions, open questions, MVP/first release, next milestones.

Then generate the draft from the template, replacing placeholders and marking gaps clearly.

### Resources

- `assets/prd-template.md` — full technical PRD template.
- `assets/prd-light-template.md` — lightweight PRD template.
