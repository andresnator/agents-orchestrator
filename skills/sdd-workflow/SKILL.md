---
name: sdd-workflow
description: "Full Arnes SDD contract: phase graph, gates, triage, escalation, state schema, handoff and envelope formats, judgment-day summary, review routing. Load when orchestrating any SDD change."
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: in-progress
---

# Arnes SDD Workflow Contract
Lazy-loaded reference for the sdd-orchestrator and the flow commands. The always-on prompts carry only the summary; this file is authoritative.

## Triage table

| Signal | Tier |
|---|---|
| 1 file, mechanical, no behavior change (typo, rename, config bump) | T0 — Direct (`sdd-build` agent, no artifacts) |
| 3 files or fewer, known area, bounded behavior change, no hot path | T1 — Quick (`/sdd-quick` pipeline) |
| New feature, unknown area, hot path (auth/payments/security/update), or estimated >400 lines | T2 — Full SDD (`/sdd-new`) |

## Escalation rules

- T0 -> T1: triggered by the second non-trivial file. `sdd-build` stops; the user switches to the sdd-orchestrator and `/sdd-quick`.
- T1 -> T2: triggered when scope exceeds T1 bounds. The pipeline stops and restarts at `propose`, inheriting the exploration handoff already produced.

## Phase graph

```
explore -> propose -> [GATE propose] -> spec || design -> [GATE plan] -> tasks -> apply -> verify -> review -> [GATE review] -> ship -> archive
```

| Phase | Agent | Inputs | Outputs |
|---|---|---|---|
| explore | sdd-explore | task description | handoffs/explore.md |
| propose | sdd-propose | handoffs/explore.md | proposal.md, handoffs/propose.md |
| spec | sdd-spec | proposal.md, handoffs/explore.md | spec.md, handoffs/spec.md |
| design | sdd-design | proposal.md, handoffs/explore.md (never spec.md — parallel) | design.md, handoffs/design.md |
| tasks | sdd-tasks | handoffs/spec.md, handoffs/design.md (+ full artifacts on demand) | tasks.md, handoffs/tasks.md |
| apply | sdd-apply | tasks.md, handoffs/spec.md, handoffs/design.md | code diff, checked tasks.md, handoffs/apply.md |
| verify | sdd-verify | spec.md, tasks.md, handoffs/apply.md | verify-report.md, handoffs/verify.md |
| review | sdd-review-quality + sdd-review-risk, or judgment-day | diff, handoffs/verify.md | envelope findings |
| ship | sdd-orchestrator via /sdd-ship | tasks.md, handoffs, verify-report.md | branch, commits, PR |
| archive | sdd-orchestrator | all artifacts | specs merged, folder archived |

## Gate definitions

A gate is one `question` tool call by the sdd-orchestrator with options approve / adjust / abort, summarizing the artifact from its handoff (never the raw file).

| Gate | After | Approves |
|---|---|---|
| propose | sdd-propose returns | proposal.md — intent, approach, scope, blast radius |
| plan | spec and design both return | spec.md + design.md as the implementation contract |
| review | review lenses or judgment-day complete | merge readiness; /sdd-ship adds its own pre-push confirmation |

`adjust` re-runs the gated phase with the user's feedback inlined. `abort` records the decision and halts the change. Every decision is appended to `gates` in state.yaml.

## state.yaml schema

Owned exclusively by the sdd-orchestrator; updated at every transition.

```yaml
change: dark-mode-toggle          # slug, matches folder name
tier: T2                          # T1 | T2 (T0 has no folder)
phase: apply                      # explore | propose | spec | design | tasks | apply | verify | review | ship | archive
gates:
  - gate: propose                 # propose | plan | review
    decision: approve             # approve | adjust | abort
    at: 2026-07-03T14:05:00Z
artifacts:
  - proposal.md
  - spec.md
created: 2026-07-03T13:40:00Z
updated: 2026-07-03T15:12:00Z
```

## Handoff format

`.arnes/changes/<change>/handoffs/<phase>.md`, at most 30 lines, written by each phase agent before finishing. Content: what the next phase needs and nothing else (decisions, paths, risks, open points). Handoffs are the default inter-phase context; full artifacts are read only on demand.

## Result envelope format

Every subagent's final message:

```
status: success | partial | blocked
executive_summary: <max 10 lines>
artifacts:
  - <paths written>
next_recommended: <next phase or action>
risks:
  - <list, or "none">
questions:
  - <only when status is blocked>
```

Subagents never ask the user anything; `blocked` + `questions[]` is the only escalation path, and the sdd-orchestrator relays via the `question` tool.

## Review routing

| Situation | Review |
|---|---|
| T1 | sdd-review-quality, advisory |
| T2 default | sdd-review-quality + sdd-review-risk in parallel, gating |
| Hot path (auth/payments/security/update) or >400 changed lines | judgment-day protocol |

## Judgment-day summary

Judges A and B run in parallel and blind. Synthesis buckets: **confirmed** (both flag the same defect independently), **suspect** (one judge), **contradiction** (they disagree on the same code). Only confirmed findings go to `jd-fix`; after fixes, both judges re-run. Maximum 2 fix rounds, then escalate to the user. Full procedure: `judgment-day` skill.

## References

- `references/state-contract.md` stores the expanded state lifecycle and archive contract.
