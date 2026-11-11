---
name: oc-handoff
description: >-
  Export portable context for a destination task on explicit request.
  Trigger: oc-handoff, export context, portable handoff.
license: MIT
metadata:
  author: andresnator
  version: 1.0.0
  status: testing
---

# Portable Handoff

## Intent

- **Goal:** Export one portable note for the user's destination task.
- **Limits:** Export only. Do not replace SDD resume or Engram. Do not delegate, change Git, edit project files, or change sessions.
- **Fails if:** The request is not explicit, the destination task or scope is unknown, or the export needs an overwrite.

## Context

- **Reads:** The user's destination task and output scope; relevant conversation evidence; selected artifact references; the destination catalog, if available.
- **Never reads:** Unrelated history, secret stores, or private data outside the selected scope.
- **Persona:** Context editor, not a run coordinator.
- **Scope:** Portable context export between sessions, tools, or people. No automatic resume.

## Expectations

- **Scenarios:** WHEN the user requests an export THEN create one note. WHEN evidence or access is uncertain THEN record the gap.
- **Done means:** Return the exact absolute file path and the remaining gaps. If export fails, return the blocker without a success claim.
- **Quality needs:** Keep verified state separate from uncertainty. Remove secrets and personal data before writing. Never transfer approval or run authority.

## Method

Create one unique file in the environment-supplied temporary directory, outside the project.
Use exclusive creation and owner-only read/write permissions (`0600`). Never overwrite a file.
If no suitable temporary directory is available, stop and report the blocker.
Include only these task-specific fields:

| Note field | Required content |
| --- | --- |
| Destination task | The requested outcome and output scope. |
| Verified state | Completed work, evidence, check results, and the source baseline when known. |
| Uncertainty | Unverified claims, missing evidence, and access gaps. |
| Pending checks | Checks that did not run or still need a result. |
| Next step | One proposed action, not permission to execute it. |
| Artifacts | Paths or links to existing artifacts, not duplicate bodies. Flag inaccessible artifacts and unverified destination access. |
| Suggested skills | Optional advice only. Do not assert availability without the destination catalog. |
| Authority | This note transfers no approval or run authority. Use the source run contract for SDD resume. |
| Temporary storage | This file can expire or disappear. It does not replace Engram or durable project artifacts. |
