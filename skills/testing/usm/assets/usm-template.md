# {Product or Feature Name} User Story Map

Remove template guidance lines from the final output.

## Metadata

| Field | Value |
| --- | --- |
| Product / Feature | {name} |
| Status | {draft/review/final} |
| Primary Actor | {primary actor} |
| Date | {date} |
| Language | {artifact language} |

## Goal & Context

{Outcome the map supports, current context, and any source inputs used such as raw idea, PRD, RFC, issue, or notes.}

## Actors

Repeat actor rows as needed. Omit secondary actors when none exist.

| Actor | Role in Map |
| --- | --- |
| {Primary Actor} | Primary journey owner |

Add one row per secondary actor when present.

## User Journey Backbone

| Order | Activity | User Intent |
| --- | --- | --- |
| 1 | {Activity 1} | {intent} |
| 2 | {Activity 2} | {intent} |
| 3 | {Activity 3} | {intent} |

## User Tasks by Activity

### {Activity 1}

- [{slice}] {concise user task}
- [{slice}] {concise user task}

### {Activity 2}

- [{slice}] {concise user task}
- [{slice}] {concise user task}

### {Activity 3}

- [{slice}] {concise user task}
- [{slice}] {concise user task}

## Slice Plan

### MVP Slice

{End-to-end slice description and why it is the first usable release.}

- {MVP task from early journey}
- {MVP task from middle journey}
- {MVP task from late journey}

### Later Release Slices

Omit this section when no later slices were planned. If included, add one bullet per release slice.

## Mermaid Story Map

```mermaid
flowchart LR
  subgraph A1[Activity 1]
    direction TB
    A1T1[Task 1]
    A1T2[Task 2]
  end

  subgraph A2[Activity 2]
    direction TB
    A2T1[Task 3]
    A2T2[Task 4]
  end

  subgraph A3[Activity 3]
    direction TB
    A3T1[Task 5]
    A3T2[Task 6]
  end

  A1 --> A2 --> A3

  classDef mvp fill:#dcfce7,stroke:#15803d,color:#052e16
  classDef later fill:#e0f2fe,stroke:#0369a1,color:#082f49

  class A1T1,A2T1,A3T1 mvp
  class A1T2,A2T2,A3T2 later
```

If the user explicitly requests a narrative journey diagram, add a Mermaid `journey` diagram here after the flowchart. Otherwise omit this note.

## Open Questions

- {Question, owner if known, and why it matters}

## Risks

- {Risk, impact, and possible mitigation}

## Assumptions

- {Assumption and what would invalidate it}

## Next Steps

- Review the MVP Slice with stakeholders.
- Convert the MVP Slice into buildable issues when ready.
- Resolve the highest-impact open questions before implementation starts.
