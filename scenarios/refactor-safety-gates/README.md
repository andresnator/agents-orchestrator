# Refactor Safety Gates Scenarios

Golden cases for reusable refactor safety gate guidance. These scenarios validate prompt behavior and handoff discipline by manual review; this repository has no runtime test framework.

## Validation checklist

- The skill remains method guidance: vocabulary, checklist steps, waivers, and compact output only.
- Primary agents coordinate sequencing, topic keys, and human gates without inspecting raw source or coverage evidence.
- Readiness roles classify weak baseline, test anchors, coverage, and mutation/equivalent evidence as blockers or human decisions.
- Refactor workers consume compact gate evidence and block on unresolved blockers instead of reshaping code.
- Waivers are never implicit and require `decided_by: human` evidence.

## Golden cases

| Case | Input | Expected behavior | Must include | Must not include |
|---|---|---|---|---|
| Primary stays thin | A primary coordinates a refactor workflow and receives topic keys plus a request to inspect coverage details directly. | Primary coordinates sequencing, topic keys, and human gates, then routes evidence gathering to the readiness role without inspecting raw evidence. | Topic-key handoff, human gate ownership, refusal to inspect raw source/coverage. | Source snippets, coverage report summaries, readiness verdict invented by the primary. |
| Weak evidence blocks readiness | Readiness role finds weak or missing baseline, test anchors, coverage, or mutation/equivalent signals for a target scope. | Readiness report marks affected gates as `blocked`, `unknown`, or `needs-human-decision` and recommends cover-first, tooling setup, waiver decision, or stop. | `gates`, `evidence.commands`, `target_scope`, `blockers`, `next_recommended`. | `refactor-slice` recommendation when blockers are unresolved, silent waiver, raw report dump. |
| Refactor worker blocks on unresolved gates | Refactor worker receives compact readiness evidence with unresolved blockers or waivers lacking `decided_by: human`. | Worker blocks before edits and reports missing evidence or failing gates. | `status: blocked`, named gate, required evidence or human decision. | Code reshaping, behavior changes, multi-slice planning. |
| Skill remains method-only | Reviewer inspects `skills/refactor-safety-gates/SKILL.md` for responsibility boundaries. | Skill defines gate vocabulary, method steps, waiver rules, consumption rules, and output shape without becoming an orchestrator or subagent. | Method-only wording, forbidden ownership list, compact output contract. | Routing ownership, state management, subagent selection, hidden orchestration. |

## Manual review notes

- Confirm `pass|blocked|needs-human-decision|unknown` appears for all four gates: `baseline`, `test_anchor`, `coverage`, and `mutation_or_equivalent`.
- Confirm waived coverage or mutation/equivalent gates require `decided_by: human`.
- Confirm the scenario suite does not introduce a reusable coverage/readiness subagent.
- Confirm no OpenSpec files are created for this change.
