---
name: oc-issue
description: "Create or enrich a GitHub issue that is ready to build. Trigger: create an issue, write a ticket, I need to build X, buildable issue, enrich an issue."
license: MIT
metadata:
  author: andresnator
  status: backlog
  version: "4.0.0"
---

# Skill: oc-issue

## Intent

- **Goal:** A GitHub issue that an agent or a human can implement without guessing.
- **Limits:** Do not implement. Search for duplicate issues before you create one. Read the repository before you ask. Ask only for a product decision that the repository cannot answer, one question at a time.
- **Fails if:** a section is missing or has placeholder text, an in-scope item has no Given/When/Then scenario, scope has no in/out boundaries, or no issue URL is returned.

## Context

- **Reads:** the target repository, the requested change, the existing issue when you enrich, and repository conventions.
- **Never reads:** unrelated issues beyond one focused duplicate query.
- **Scope:** "create an issue", "write a ticket", "I need to build X", buildable issues, and enrichment of a referenced issue.

## Expectations

- **Scenarios:**
  - WHEN you create THEN fill every section of `assets/issue-template.md` and create the issue with the title and labels below.
  - WHEN the user gives an issue number THEN fetch it, keep useful content, fill missing sections from the repository, update the body, and add `ready-to-build`.
- **Done means:** the issue URL or reference, the labels, the duplicate search result, a short buildability summary, and remaining assumptions.
- **Quality needs:** intent says why. Type is `feature`, `bugfix`, `refactor`, or `chore`. Technical context names affected areas or says "unknown".

## Method

- Template: `assets/issue-template.md`.
- Title: `<type>(<scope>): <concise description>`.

| Type | Labels |
|---|---|
| feature | `enhancement`, `ready-to-build` |
| bugfix | `bug`, `ready-to-build` |
| refactor | `refactor`, `ready-to-build` |
| chore | `chore`, `ready-to-build` |

If a label does not exist in the repository, create the issue without it and report it.
