---
name: sdd-draft-change
description: "Trigger: draft change, ready-for-sdd change, SDD planning. Draft one human-readable change.md before implementation."
license: MIT
metadata:
  author: andresnator
  version: "2.0.2"
  status: testing
---

## Contract

Create one `change.md` per bounded change or roadmap slice. It replaces proposal, design, delta-spec, and tasks documents before implementation. Use `assets/change-template.md`.

## Rules

- Target at most 900 words. Split oversized work into roadmap slices; do not add companion phase documents.
- Use short complete sentences. Keep paths, symbols, commands, URLs, technical terms, numbers, and Markdown exact.
- Omit empty sections and filler. Keep the artifact clear to a human; do not use cryptic A2A fragments inside it.
- Qualify every behavior as `<capability>/<requirement>`. `RENAME` uses `<old-capability>/<old-requirement> -> <new-capability>/<new-requirement>`. Preserve `ADD | MODIFY | REMOVE | RENAME` intent and observable `WHEN`/`THEN` scenarios; canonical merge never guesses a capability.
- `Work` groups use small ordered checkboxes and real paths. Add `Files:` when scope is known; parallelize only disjoint scopes, otherwise serialize.
- Every `Work` group requires `Skills: <comma-separated names | none>` selected with `sdd-execution-skills`. Missing fields are invalid; use names, never paths.
- The status marker is always line one. A planner writes `Status: ready-for-sdd` and omits execution choices. A roadmap slice adds `Roadmap: <goal> | Slice: <n>/<total>` on line two. Direct SDD writes `Status: active` with its choices. SDD preserves marker lines and adds choices immediately after them without redrafting the body.
- Artifacts default to English. Planning is read-only except for the approved `change.md`; never edit production code, commit, or push.

## Self-check

- One file contains outcome, scope, behavior, approach, work, and verification needed for execution.
- Every claim is evidenced or explicitly marked as an open question.
- Every behavior identifier names its exact canonical capability and requirement.
- Every task is actionable and verifiable; behavior changes do not hide in tasks.
- Every work group names its implementation skills or `none`.
- Risks and open questions contain only real, non-empty items.

## Resource

- `assets/change-template.md`
