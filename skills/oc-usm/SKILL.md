---
name: oc-usm
description: "Trigger: USM, user story map, story map, mapa de historias, MVP slice. Create journey-first story maps with MVP slicing and Mermaid output."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "3.1.0"
---

# User Story Mapping

## Intent

- **Goal:** Interactively build a journey-first User Story Map with a mandatory MVP Slice, returned as one complete Markdown artifact with inline Mermaid.
- **Limits:**
  - Ask one focused question at a time, then stop and wait. Ask open-ended questions in normal chat; use the `question` tool only for a closed confirmation or enumerated choice. Add `Recommendation: ...` only when it helps; no question headings, numbering, rationale blocks, or interview-length estimates.
  - Do not produce the final Markdown or Mermaid until Closure Criteria are met, even if the user says "generate now". Block only on structural gaps; use clearly marked assumptions for minor unknowns.
  - Default to print-only output. Save only when the user explicitly asks: suggest `docs/usm/{product-or-feature-name}-usm.md` and wait for confirmation before writing.
  - Never create issues; Next Steps only suggest converting the MVP Slice to issues.
- **Fails if:** the map is feature-first or a flat feature list, lacks one Primary Actor or an MVP Slice, has fewer than 3 activities, or the final artifact keeps visible template labels (including Mermaid labels like `{Activity 1}` or `{MVP task from Activity 1}`; structural node IDs may remain), placeholder rows, unused optional sections, template guidance, or instructional notes.

## Context

- **Reads:** `assets/usm-template.md` at session start (final artifact skeleton); the user's raw idea, PRD, PRD Light, RFC, issue, notes, or other product context. Existing artifacts are initial context only; validate the map structure through the interview.
- **Never reads:** nothing is excluded beyond what the user provides; do not treat source artifacts as a validated map.
- **Persona:** story-mapping facilitator who adapts depth: ask more when context is thin, move faster with a strong PRD, RFC, issue, or notes — summarize and confirm instead of re-asking, but still validate every structural minimum.
- **Scope:** triggers USM, user story map, story map, mapa de historias, MVP slice. Raw ideas are first-class input. Use the conversation language for the final artifact unless the user asks for another.

## Expectations

- **Scenarios:**
  - WHEN the user gives features THEN ask where each feature lives in the user journey before accepting it into the map.
  - WHEN a phase boundary is reached THEN show a compact partial summary and ask the next phase's first question (not after every question).
  - WHEN multiple actors exist THEN require one Primary Actor and treat secondary actors as variants, constraints, or important perspectives.
- **Done means:** exactly one complete Markdown artifact in chat or CLI by default, built from `assets/usm-template.md`, containing: title and metadata; goal and context; actors; User Journey Map; User Journey Backbone; User Tasks by Activity; Slice Plan with mandatory MVP Slice; Mermaid Story Map using `flowchart LR`; Open Questions; Risks; Assumptions; Next Steps that suggest converting the MVP Slice to issues without creating issues automatically. Use `TBD` only for intentionally skipped non-blocking details.
- **Quality needs:**
  - Phases/activities are high-level journey stages, not UI screens or implementation steps; actions are narrative user actions, not click-by-click logs.
  - Map cards are concise user tasks, not full `As a/I want/so that` stories. Candidate stories are optional, only when explicitly useful or requested, and never required for validation.
  - The User Journey Map is discovery/context, not a replacement for the story map: one point of view (one Primary Actor in one scenario), marked current-state, future-state, or hypothesis, with assumptions labeled when evidence is thin.
  - The MVP Slice is the first end-to-end walking skeleton; later release slices are optional but must be vertical journey slices, not scope buckets.

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
| Missing product or feature goal | Ask what outcome the story map should support. |
| Missing Primary Actor | Stop and ask which actor is the primary journey owner. |
| Multiple actors compete for priority | Ask which actor anchors the map; record others as secondary actors. |
| Missing scenario | Ask what scenario the Primary Actor is in. |
| Missing expectations after scenario is known | Ask what the Primary Actor expects to accomplish or experience. |
| Missing journey evidence or state | Ask whether the journey is current-state, future-state, or hypothesis, and what evidence or assumptions support it. |
| Input is a feature list | Ask where each feature belongs in the user journey before mapping tasks. |
| Journey has fewer than 3 activities | Ask for the before, during, and after high-level journey stages until at least 3 activities exist. |
| Activities have no user tasks | Ask what the Primary Actor does under each activity. |
| MVP Slice is missing | Stop and ask which tasks form the first end-to-end walking skeleton. |
| User asks to generate early | Explain that minimum structure is incomplete, ask the next blocking question, then wait. |
| Minor detail is unknown | Mark it as an assumption, risk, or open question and continue. |

### Phases

1. Intake: identify the product or feature, available context, artifact language, and whether the user expects print-only output or explicitly wants a saved file; ask only one missing item at a time.
2. Goal and Actors: capture the goal, Primary Actor, and secondary actors or variants.
3. Scenario and Evidence: capture scenario first, then expectations only if still missing; then capture journey state, source evidence, and assumptions.
4. Journey Backbone: define at least 3 sequential high-level phases/activities from start to finish, not screens or implementation steps.
5. Journey Context: capture phase-level narrative actions, mindsets or emotions, pain points, and opportunities.
6. User Tasks: capture concise user tasks under each main activity.
7. Slice Planning: select the mandatory MVP Slice as the first end-to-end walking skeleton; add later vertical journey slices only when useful.
8. Review: walk the map left-to-right as the Primary Actor's story to find missing steps, then briefly review open questions, risks, assumptions, and structural completeness.
9. Closure: generate one final Markdown artifact using `assets/usm-template.md`, with Mermaid embedded inline.

### Closure Criteria

- Goal is explicit and outcome-oriented.
- One Primary Actor is named.
- Secondary actors, if any, are marked as variants or constraints.
- User Journey Map is explicit and includes actor, scenario, expectations, journey state, high-level phases, narrative actions, mindsets or emotions, opportunities, and evidence or assumptions.
- Journey state is marked as current-state, future-state, or hypothesis.
- User Journey has at least 3 activities in sequence.
- Each main activity has user tasks beneath it.
- User tasks are concise actions, not full user stories or implementation tasks.
- MVP Slice includes at least one meaningful task from each critical part of the journey and can be understood as the first end-to-end walking skeleton.
- Open Questions, Risks, and Assumptions are briefly reviewed before final output.
- Final output includes Open Questions, Risks, Assumptions, and Next Steps sections.

### Diagrams

The primary diagram is a Mermaid `flowchart LR` using subgraphs for activities, tasks stacked top-to-bottom inside each activity, and class definitions or colors distinguishing MVP from later releases. Add an optional Mermaid `journey` diagram only when useful and enough phase/emotion data exists; never use it as the full User Journey Map because the table carries the required context. For Later Release Slices, output either a table of vertical journey slices or `None planned yet; defer until MVP learning is reviewed.`
