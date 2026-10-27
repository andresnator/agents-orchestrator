---
name: oc-issue
description: >
  Creates agent-ready GitHub issues that are ready to build. Formerly framed as
  sdd-issue / SDD-ready issue creation. Use when creating a buildable issue,
  implementation-ready ticket, SDD-ready issue, preparing work for an
  orchestrator, or when the user says "create an issue", "write a ticket", or
  "I need to build X". Also use when the user references an existing issue and
  wants it enriched with scope, constraints, acceptance scenarios, and technical
  context.
license: MIT
metadata:
  author: andresnator
  status: backlog
  version: "3.1.0"
---

# Skill: oc-issue

## Intent

- **Goal:** Create or enrich a GitHub issue that another agent or human can implement without guessing: intent, type, scope, acceptance scenarios, technical context, constraints, and priority.
- **Limits:** Do not run the implementation, orchestrate SDD phases, or invent missing product decisions; interview the user (at most one question at a time) when critical fields are missing. Search existing issues for likely duplicates before creating a new one.
- **Fails if:** any section is missing or keeps placeholder text, an in-scope item lacks observable Given/When/Then acceptance scenarios, scope lacks in-scope or out-of-scope boundaries, or no issue URL/reference is returned.

## Context

- **Reads:** the target repository or project; the intended change, bug, refactor, or chore; known constraints, affected files/modules, and acceptance expectations; the existing issue when enriching; repository conventions.
- **Never reads:** unrelated issues beyond a focused duplicate query.
- **Persona:** issue author preparing buildable, orchestrator-ready work.
- **Scope:** creating a buildable issue, implementation-ready ticket, SDD-ready issue, or preparing work for an orchestrator ("create an issue", "write a ticket", "I need to build X"), or enriching a referenced issue. This is the renamed capability for the older `sdd-issue` wording; treat legacy phrases like "SDD-ready issue" as compatible triggers, but prefer `oc-issue` in new documentation.

## Expectations

- **Scenarios:**
  - WHEN creating THEN clarify gaps, search duplicates, fill every template section, validate scenarios per in-scope item, and create the issue with a conventional title and labels.
  - WHEN the user references an issue number THEN fetch it, preserve useful existing content, interview for missing sections, replace or append the structured body, and add `sdd-ready` once the structure is complete.
- **Done means:** return the issue URL or updated issue reference, labels applied, a duplicate search result summary, a short summary of what made it buildable, and any remaining assumptions or follow-up questions.
- **Quality needs:** intent explains why the change matters; type is one of `feature`, `bugfix`, `refactor`, or `chore`; technical context names affected areas or says they are unknown; constraints and priority are filled; no placeholder text remains.

## Method

### Issue template

````markdown
## Intent

<Why this change is needed. Explain the problem or opportunity, not only the requested work.>

## Type

<feature | bugfix | refactor | chore>

## Scope

### In Scope
- <What will be built or changed>

### Out of Scope
- <What will not be changed>

## Acceptance Scenarios

### Scenario: <descriptive name>
- GIVEN <precondition>
- WHEN <action or trigger>
- THEN <observable expected result>

### Scenario: <descriptive name>
- GIVEN <precondition>
- WHEN <action or trigger>
- THEN <observable expected result>

## Technical Context

- **Affected files/modules**: <paths, packages, services, or unknown>
- **Related specs/docs**: <links or none>
- **Dependencies**: <new or existing dependencies, or none>
- **Breaking changes**: <yes/no and details>

## Constraints

- <Architectural, product, security, compatibility, or workflow constraints>

## Priority

<critical | high | medium | low>
````

### Title and labels

Title: `<type>(<scope>): <concise description>`. Apply `sdd-ready` when the issue is structured for automated SDD consumption.

| Type | Labels |
|---|---|
| feature | `enhancement`, `sdd-ready` |
| bugfix | `bug`, `sdd-ready` |
| refactor | `refactor`, `sdd-ready` |
| chore | `chore`, `sdd-ready` |
