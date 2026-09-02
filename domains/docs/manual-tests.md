# Docs manual tests

Run these cases after changing documentation commands or their routed skills. Use a disposable repository so artifact creation never touches production documentation.

## Quick path

1. Install the current checkout's `docs,common` domains into a disposable project.
2. Run the affected IDs shown in the catalog check.
3. Inspect only the selected skill's artifact and remove it afterward.

### MT-DOCS-DOC-ROUTING

- **Title:** Route a document to one specific skill
- **Coverage key:** `docs/routing/specific-skill`
- **Applies to:** `domains/docs/commands/doc.md`, `domains/docs/skills/buildable-issue/**`, `domains/docs/skills/cognitive-doc-design/**`, `domains/docs/skills/jira-spike/**`, `domains/docs/skills/jira-task/**`, `domains/docs/skills/jira-user-story/**`, `domains/docs/skills/rfc/**`, `domains/docs/skills/slidev-retro-deck/**`, `domains/docs/skills/summarize/**`, `domains/docs/skills/usm/**`, `domains/docs/skills/whisper-extract/**`
- **Preconditions:** Use a disposable repository and a clear request for one supported document type, such as an implementation-ready issue.
- **Steps:**
  1. Run `/doc <clear-request>` and answer only information required by that document type.
  2. Inspect the chosen skill and final artifact.
- **Expected result:** `/doc` selects exactly one most-specific skill, does not recurse through another command or override that skill, and creates only the requested artifact.
- **Cleanup:** Remove the generated artifact and disposable repository.

### MT-DOCS-PRD-ROUTING

- **Title:** Route an MVP request to a lightweight PRD
- **Coverage key:** `docs/prd/light-routing`
- **Applies to:** `domains/docs/commands/prd.md`, `domains/docs/skills/prd/**`, `domains/docs/skills/prd-light/**`
- **Preconditions:** Use a disposable repository and a clear early-stage MVP request with no regulated or cross-team constraints.
- **Steps:**
  1. Run `/prd <mvp-request>`.
  2. Complete the selected interview and inspect the resulting PRD structure.
- **Expected result:** The command loads `prd-light` immediately, asks no routing question when the signal is clear, and leaves interview, draft, and write behavior to that skill.
- **Essential negative variant:** Submit a request whose scope omits whether it is lightweight or formal and confirm one plain-language triage question appears before either skill loads.
- **Cleanup:** Remove the generated PRD and disposable repository.

### MT-DOCS-ADR

- **Title:** Record one technical decision as an ADR
- **Coverage key:** `docs/adr/decision-record`
- **Applies to:** `domains/docs/commands/adr.md`, `domains/docs/skills/adr/**`
- **Preconditions:** Use a disposable repository with a concrete technical decision, two real options, and a documentation destination.
- **Steps:**
  1. Run `/adr <decision>` and answer only unresolved context or trade-off questions.
  2. Inspect the created ADR for context, decision, options, consequences, and evidence.
- **Expected result:** One ADR records the actual decision and trade-offs in the requested language, preserves repository facts, and makes no implementation or Git change.
- **Cleanup:** Remove the ADR and disposable repository.
