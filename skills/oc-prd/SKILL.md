---
name: oc-prd
description: "Trigger: PRD, product requirements, technical product spec, PRD light, quick PRD, lightweight PRD, MVP requirements. Create rigorous PRDs (mode=full) for high-stakes, cross-team, regulated, or security-sensitive work, or lightweight PRDs (mode=light) for small features, internal tools, and early ideas."
license: MIT
metadata:
  author: andresnator
  status: done
  version: "5.0.0"
---

# PRD

## Intent

- **Goal:** A PRD in the selected mode, filled into the mode template through an interview.
- **Limits:**
  - Use the given `mode`. If no mode is given, select `light` for quick or light requests, MVPs, early ideas, internal tools, and small features. Select `full` for formal requests and for high-stakes, cross-team, security, compliance, API-heavy, or regulated work.
  - The bare word "PRD" is not a depth signal. Light signals win if no full signal is present. If the mode is still ambiguous, ask one triage question.
  - Ask one question at a time. Work one phase at a time. Do not send the template as a questionnaire.
  - Do not invent facts. Record unknowns as open questions, assumptions, or `TBD`.
  - Full: allow `N/A` only with a short justification. Light: at most one follow-up for each phase.
- **Fails if:**
  - A must-have requirement has no acceptance criteria, or risks and open questions are hidden.
  - Full: traceability from problem to goals, requirements, criteria, metrics, risks, and delivery is broken.
  - Light: the MVP is not identified, or the interview becomes a formal review.

## Context

- **Reads:** the mode template at session start: `assets/prd-template.md` (full) or `assets/prd-light-template.md` (light). An existing PRD when you resume.
- **Never reads:** the template of the other mode.
- **Persona:** full: rigorous interviewer who challenges vague requirements. Light: pragmatic partner who prefers a useful draft.
- **Scope:** product and technical requirements for a feature or product.

## Expectations

- **Scenarios:**
  - WHEN you resume a PRD THEN read it, summarize complete and incomplete sections, and continue at the first incomplete phase.
  - WHEN a full-mode metric is not measurable THEN ask for target, baseline, and method, or mark `TBD` with an owner.
  - WHEN (light) a missing detail does not block alignment THEN record an open question and continue.
- **Done means:** the PRD in Markdown from the mode template, then a review request that lists remaining `TBD` items and asks for a save path. Default path: `PRD-{product-name}-v{version}.md` (full) or `PRD-Light-{product-name}-v{version}.md` (light).
- **Quality needs:** each goal has a measurable or `TBD` success signal. Each must-have connects to a goal. Full: security and dependencies include impact and fallback.

## Method

Phases follow the template sections.

- Full: metadata, Overview, Goals and Success, Users and Use Cases, Requirements and Acceptance, Quality/Security/Dependencies, Architecture and Interfaces, Risks and Open Questions, Delivery and Traceability.
- Light: Context and Goals, Users and Scenarios, Requirements, Approach and Constraints, Risks/Open Questions/Delivery.
