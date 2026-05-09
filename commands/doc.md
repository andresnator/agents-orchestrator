# /doc

## Purpose

Start a documentation-oriented request from one line of intent, then hand off to the smallest matching documentation skill.

## Invocation

```text
/doc <qué querés documentar?>
```

If the subject is missing, ask at most one clarifying question before continuing.

## Uses

| Request shape | Skill to load | Purpose |
|---|---|---|
| Architecture or technical decision | `adr` | Record why a decision was made |
| Technical proposal, design doc, or RFC | `rfc` | Propose a technical change for review |
| Product requirements | `prd` | Define full product requirements |
| Lightweight MVP/internal requirements | `prd-light` | Define quick requirements without heavy ceremony |
| Research or feasibility task | `spike` | Create a Jira spike for investigation |
| Agent-ready implementation issue | `buildable-issue` | Create or enrich a buildable GitHub issue |
| Acceptance criteria | `write-ac` | Write testable Given/When/Then criteria |
| General review-facing docs | `cognitive-doc-design` | Shape clear, low-cognitive-load documentation |

## Output

Return one of:

- the selected skill and the next action it should perform;
- one clarifying question when the documentation type changes the output materially;
- a concise documentation plan or draft when no exact skill applies;
- a redirect when the request is not documentation work.

## Boundaries

- Do not duplicate skill instructions here; load and follow the selected skill.
- Do not act as a multi-step router or substitute orchestrator.
- Do not create files, issues, PRs, or external artifacts unless the selected skill explicitly requires it.
- Choose the smallest useful documentation shape when the request is clear enough.
