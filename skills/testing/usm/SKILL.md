---
name: usm
description: |
  Interactively creates User Story Maps with a journey-first structure, mandatory MVP slice, and inline Mermaid output.
  Trigger on "USM", "usm", "User Story Mapping", "user story map", "story map", "mapear historias", "mapa de historias", "planificación de producto", "MVP slice", or "release slicing".
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
---

# User Story Mapping

## Activation Contract

Use this skill to interactively create a User Story Map for a raw idea, PRD, PRD Light, RFC, issue, notes, or other product context. Raw ideas are first-class input. Existing artifacts are initial context only; validate the story map structure through the interview.

Always read `references/usm-template.md` at the start of the session and use it as the final artifact skeleton.

## Hard Rules

- Ask one focused question at a time, then stop and wait for the user's answer.
- Use one adaptive-depth flow: ask more when context is thin, and move faster when strong PRD, RFC, issue, or notes are provided.
- With strong source input, summarize and confirm instead of re-asking already answered questions, but still validate every structural minimum in Closure Criteria.
- Show partial summaries at phase boundaries, not after every question.
- Do not produce the final Markdown or Mermaid until Closure Criteria are met, even if the user says "generate now".
- Block only on structural gaps; use clearly marked assumptions for minor unknowns.
- Build the map journey-first, not feature-first.
- If the user gives features, ask where each feature lives in the user journey before accepting it into the map.
- Do not accept a flat feature list as the map structure.
- Map cards are concise user tasks, not full `As a/I want/so that` stories.
- Candidate stories are optional output only when explicitly useful or requested; they are never required for validation.
- Support multiple actors, but require one Primary Actor. Treat secondary actors as variants, constraints, or important perspectives.
- Require an MVP Slice that cuts end-to-end through the journey. Later release slices are optional.
- Default to print-only output. Do not save files unless the user explicitly asks.
- If saving is requested, suggest `docs/usm/{product-or-feature-name}-usm.md` and wait for confirmation before writing.
- Use the conversation language for the final artifact unless the user explicitly asks for another language.

## Question Format

Every interview question must use this exact structure:

```markdown
### Question N — [focused USM question]

**Why this matters:** [why this decision affects the User Story Map]

**Estimated remaining questions in this phase:** ~M

**Recommended answer:** [short recommended/default answer when useful]
```

Keep `N` sequential across the whole interview. Keep `M` adaptive within the current phase.

## Decision Gates

| Situation | Action |
| --- | --- |
| Missing product or feature goal | Ask what outcome the story map should support. |
| Missing Primary Actor | Stop and ask which actor is the primary journey owner. |
| Multiple actors compete for priority | Ask which actor anchors the map; record others as secondary actors. |
| Input is a feature list | Ask where each feature belongs in the user journey before mapping tasks. |
| Journey has fewer than 3 activities | Ask for the before, during, and after steps until at least 3 activities exist. |
| Activities have no user tasks | Ask what the Primary Actor does under each activity. |
| MVP Slice is missing | Stop and ask which tasks form the first end-to-end usable slice. |
| User asks to generate early | Explain that minimum structure is incomplete, ask the next blocking question, then wait. |
| Minor detail is unknown | Mark it as an assumption, risk, or open question and continue. |

## Execution Phases

1. Intake: identify the product or feature, available context, artifact language, and whether the user expects print-only output or explicitly wants a saved file.
2. Goal and Actors: capture the goal, Primary Actor, and secondary actors or variants.
3. Journey Backbone: define at least 3 sequential user activities from start to finish.
4. User Tasks: capture concise user tasks under each main activity.
5. Slice Planning: select the mandatory MVP Slice across the full journey; add later release slices only when useful.
6. Review: briefly review open questions, risks, assumptions, and structural completeness.
7. Closure: generate one final Markdown artifact using `references/usm-template.md`, with Mermaid embedded inline.

At each phase boundary, provide a compact summary and ask the next phase's first question.

## Closure Criteria

- Goal is explicit and outcome-oriented.
- One Primary Actor is named.
- Secondary actors, if any, are marked as variants or constraints.
- User Journey has at least 3 activities in sequence.
- Each main activity has user tasks beneath it.
- User tasks are concise actions, not full user stories or implementation tasks.
- MVP Slice includes at least one meaningful task from each critical part of the journey and can be understood end-to-end.
- Open Questions, Risks, and Assumptions are briefly reviewed before final output.
- Final output includes Open Questions, Risks, Assumptions, and Next Steps sections.

## Output Contract

Return exactly one complete Markdown artifact in chat or CLI by default. Embed Mermaid inline in the artifact.

The primary diagram must be a Mermaid `flowchart LR` using subgraphs for activities. Stack tasks top-to-bottom inside each activity. Use class definitions or colors to distinguish MVP from later releases. If the user explicitly asks for a narrative diagram, add an optional Mermaid `journey` diagram after the flowchart.

The final artifact must include:

- Title and metadata.
- Goal and context.
- Actors.
- User Journey Backbone.
- User Tasks by Activity.
- Slice Plan with mandatory MVP Slice.
- Mermaid Story Map using `flowchart LR`.
- Open Questions.
- Risks.
- Assumptions.
- Next Steps that suggest converting the MVP Slice to issues without creating issues automatically.

Never leave placeholder instructions in the final artifact. Use `TBD` only for intentionally skipped non-blocking details.

## References

- `references/usm-template.md` — User Story Map output template.
