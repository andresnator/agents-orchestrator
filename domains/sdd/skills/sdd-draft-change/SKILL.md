---
name: sdd-draft-change
description: "Trigger: draft change, ready-for-sdd change, SDD planning. Draft one human-readable change.md before implementation."
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: testing
---

## Contract

Create one `change.md` per bounded change or roadmap slice. It replaces proposal, design, delta-spec, and tasks documents before implementation. Use `assets/change-template.md`.

## Rules

- Target at most 900 words. Split oversized work into roadmap slices; do not add companion phase documents.
- Use short complete sentences. Keep paths, symbols, commands, URLs, technical terms, numbers, and Markdown exact.
- Omit empty sections and filler. Keep the artifact clear to a human; do not use cryptic A2A fragments inside it.
- Preserve `ADD | MODIFY | REMOVE | RENAME` intent and observable `WHEN`/`THEN` scenarios so verified behavior can later merge into canonical specs.
- `Work` groups use small ordered checkboxes and real paths. Add `Files:` when scope is known; parallelize only disjoint scopes, otherwise serialize.
- A planner writes `Status: ready-for-sdd` and omits the execution-choice line. Direct SDD and SDD Lite write `Status: active` with their choices. SDD preserves the producer marker and adds choices immediately below it at adoption without redrafting the body.
- Artifacts default to English. Planning is read-only except for the approved `change.md`; never edit production code, commit, or push.

## Self-check

- One file contains outcome, scope, behavior, approach, work, and verification needed for execution.
- Every claim is evidenced or explicitly marked as an open question.
- Every task is actionable and verifiable; behavior changes do not hide in tasks.
- Risks and open questions contain only real, non-empty items.

## Resource

- `assets/change-template.md`
