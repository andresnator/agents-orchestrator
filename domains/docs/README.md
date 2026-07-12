# Docs Domain

Product documentation, Jira tickets, English tutoring, summaries, and transcription-oriented skills.

Agent entry: `english-tutor`.

Commands: `doc`, `prd`, `english`, `decide` (grilling-style decision interview that converges into an ADR).

Assumes the `common` domain is installed: `grilling` and `native-question-ux` live there.

```mermaid
graph TD
  commands[Docs commands] --> docs[documentation skills]
  prd[prd] --> product[PRD / RFC / ADR / Jira / story map]
  english[english] --> tutor[english-tutor]
  doc[doc] --> writing[writing and synthesis skills]
  writing -.-> common[common output skills]
```
