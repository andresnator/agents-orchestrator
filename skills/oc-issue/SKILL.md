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
  version: "3.1.1"
---

# Skill: oc-issue

## Intent

- **Goal:** A GitHub issue that an agent or a human can implement without guessing.
- **Limits:** Do not implement or run SDD phases. Do not invent product decisions: ask one question at a time. Search for duplicate issues before you create one.
- **Fails if:** a section is missing or has placeholder text, an in-scope item has no Given/When/Then scenario, scope has no in/out boundaries, or no issue URL is returned.

## Context

- **Reads:** the target repository, the requested change, the existing issue when you enrich, and repository conventions.
- **Never reads:** unrelated issues beyond one focused duplicate query.
- **Persona:** issue author who prepares buildable work.
- **Scope:** "create an issue", "write a ticket", "I need to build X", SDD-ready issues, and enrichment of a referenced issue. Legacy `sdd-issue` phrases are compatible triggers.

## Expectations

- **Scenarios:**
  - WHEN you create THEN fill every section of `assets/issue-template.md` and create the issue with the title and labels below.
  - WHEN the user gives an issue number THEN fetch it, keep useful content, ask for missing sections, update the body, and add `sdd-ready`.
- **Done means:** the issue URL or reference, the labels, the duplicate search result, a short buildability summary, and remaining assumptions.
- **Quality needs:** intent says why. Type is `feature`, `bugfix`, `refactor`, or `chore`. Technical context names affected areas or says "unknown".

## Method

- Template: `assets/issue-template.md`.
- Title: `<type>(<scope>): <concise description>`.

| Type | Labels |
|---|---|
| feature | `enhancement`, `sdd-ready` |
| bugfix | `bug`, `sdd-ready` |
| refactor | `refactor`, `sdd-ready` |
| chore | `chore`, `sdd-ready` |
