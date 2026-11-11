---
name: oc-usm
description: "Trigger: USM, user story map, story map, mapa de historias, MVP slice. Create journey-first story maps with MVP slicing and Mermaid output."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "4.0.1"
---

# User Story Mapping

## Intent

- **Goal:** A journey-first User Story Map with a mandatory MVP Slice, as one Markdown artifact with inline Mermaid.
- **Limits:**
  - Ask one question at a time, then wait. Ask more when context is thin. Summarize and confirm when context is strong.
  - Do not produce the final artifact before the Closure criteria are true, also if the user says "generate now". Block only on structural gaps. Mark minor unknowns as assumptions.
  - Print only. Save only on explicit request: suggest `docs/usm/{product-or-feature-name}-usm.md` and wait for confirmation.
  - Do not create issues.
- **Fails if:** the map is feature-first or a flat feature list, has no Primary Actor or MVP Slice, has fewer than 3 activities, or keeps template labels (for example `{Activity 1}`), placeholder rows, unused optional sections, or template notes. Structural Mermaid node IDs can stay.

## Context

- **Reads:** `assets/usm-template.md` at session start; the user's idea, PRD, RFC, issue, or notes. Source artifacts are initial context, not a validated map.
- **Scope:** triggers USM, user story map, story map, mapa de historias, MVP slice. Write the artifact in the conversation language.

## Expectations

- **Scenarios:**
  - WHEN the user gives features THEN ask where each feature is in the journey before you map it.
  - WHEN multiple actors exist THEN require one Primary Actor. Record the others as variants or constraints.
  - WHEN a phase ends THEN show a compact partial summary.
- **Done means:** one Markdown artifact from `assets/usm-template.md`: metadata, goal, actors, User Journey Map, Backbone, User Tasks by Activity, Slice Plan with MVP Slice, Mermaid `flowchart LR`, Open Questions, Risks, Assumptions, and Next Steps that suggest MVP-to-issues conversion.
- **Quality needs:**
  - Activities are high-level journey stages, not screens or implementation steps.
  - Cards are concise user tasks, not full `As a/I want/so that` stories.
  - The User Journey Map has one point of view and is marked current-state, future-state, or hypothesis.
  - The MVP Slice is the first end-to-end walking skeleton. Later slices are vertical journey slices, not scope buckets.

## Method

### Closure criteria

- The goal is explicit. One Primary Actor is named.
- The User Journey Map has actor, scenario, expectations, state, phases, actions, emotions, opportunities, and evidence or assumptions.
- At least 3 activities in sequence, each with user tasks.
- The MVP Slice has a task from each critical part of the journey.
- Open Questions, Risks, and Assumptions are reviewed with the user.

### Diagrams

- Main diagram: Mermaid `flowchart LR`, one subgraph for each activity, tasks top-to-bottom, classes that separate MVP from later releases.
- Add a Mermaid `journey` diagram only when phase and emotion data exist. It does not replace the journey table.
- If no later slices exist, write `None planned yet; defer until MVP learning is reviewed.`
