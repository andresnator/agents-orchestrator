---
name: fable-planning
description: "Trigger: deep plan, plan like Fable, planificar a fondo, fable plan. Evidence-first planning with calibrated questions, edge validation, and executable verification."
license: MIT
metadata:
  author: andresnator
  status: in-progress
  version: "2.0.0"
---

## Contract

Plan before implementation. Read the relevant code; never edit code, build, install, test, commit, or push. Planning artifacts are the only writes.

## Method

1. **Evidence first.** Verify implementations, contracts, callers, tests, and reusable `path:symbol` elements. Every claim has `path:line` evidence or is `hypothesis`. Record rejected alternatives briefly.
2. **Ask only decisions.** Explore anything the repository can answer. Ask one grouped round for genuine scope, product, or acceptance choices, with recommended answers; do not re-ask decided points.
3. **Validate edges.** Every edge is handled, explicitly out of scope, or an open question. See `references/edge-validation.md`.
4. **Stay proportional.** Keep only information that changes execution. A small plan may contain Context, Changes, and Verification only.
5. **Prove the real flow.** End with executable commands or an observable end-to-end flow and expected result.

## Decision gates

- Split an oversized executable goal into ordered roadmap slices; plan only the next unblocked slice.
- Resolve load-bearing hypotheses before handoff or move them out of scope.
- Missing optional skills degrade to plain chat, never to missing discipline.

## Outputs

- Decision or investigation: one document from `assets/plan-template.md`.
- Executable change with an SDD handoff: one `change.md` using `sdd-draft-change`, `Status: ready-for-sdd`, and all decisions/evidence needed to execute.
- Oversized change: a roadmap plus one ready `change.md` for the next slice.

Before returning, verify evidence, edges, reusable symbols, proportionality, and end-to-end verification. Report the artifact path and next route in 2-4 lines.

## References

- `assets/plan-template.md`
- `references/edge-validation.md`
- `references/question-economy.md`
