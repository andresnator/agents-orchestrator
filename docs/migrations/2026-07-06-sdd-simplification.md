# 2026-07-06 — SDD Simplification: harness → orchestraitor

## Why

The sdd domain had grown two parallel, disconnected SDD systems:

1. A **stateful harness** (14 agents, 6 commands): `sdd-orchestrator` with T0/T1/T2 triage, 8 phase subagents, 5 review agents, `state.yaml` ownership, result envelopes and per-phase handoffs copy-pasted across ~11 agent files, writing under `.arnes/changes/`.
2. The **interview skills** (`grill` sdd mode + `sdd-draft-*`): one-question-at-a-time drafting of the same artifacts under `openspec/changes/`, symlinked into the domain but referenced by no agent or command.

For a solo developer this was over-engineered: commands added friction, automatic triage got in the way, and the protocol machinery (envelopes, handoffs, state schema) existed to solve coordination problems that a single hybrid agent does not have.

## What changed

- **New primary agent `orchestraitor`** (name after "andresnaitor"): interviews, drafts, implements, and archives itself. Delegates only exploration (`sdd-explore`) and adversarial review (`jd-judge-a/b`, `jd-fix`). Kickoff asks mode (interactive/automatic), TDD, and judgment once per change.
- **Agents 14 → 5**: removed `sdd-orchestrator`, `sdd-build`, `sdd-propose`, `sdd-spec`, `sdd-design`, `sdd-tasks`, `sdd-apply`, `sdd-verify`, `sdd-review-quality`, `sdd-review-risk`. Kept `sdd-explore` (simplified), `jd-judge-a`, `jd-judge-b`, `jd-fix` (envelope/state protocol removed).
- **Commands 6 → 0**: removed `sdd-new`, `sdd-continue`, `sdd-quick`, `sdd-review`, `sdd-ship`, `sdd-status`. The flow starts conversationally.
- **Skills removed**: `sdd-workflow`, `context-handoff`, `elicit` (top-level dirs + sdd symlinks) — their content duplicated what was inlined in the deleted agents, and nothing loaded them.
- **Skills updated (major bump to 2.0.0)**: `grill`, `sdd-draft-proposal`, `sdd-draft-spec`, `sdd-draft-design`, `sdd-draft-tasks` now write under `.orchestraitor/changes/` instead of `openspec/changes/`; dangling `sdd-apply` references repointed to the orchestraitor.
- **Symlink added**: `domains/sdd/skills/judgment-day` (was referenced but never linked into the domain).
- **State/artifacts**: `.arnes/` (state.yaml, handoffs, envelopes) is gone. File management follows OpenSpec conventions under `.orchestraitor/`: canonical `specs/<capability>/spec.md`, active `changes/<name>/` (proposal, design, spec deltas, tasks), and `changes/archive/<date>-<name>/` with deltas merged into canonical specs on archive.

## Records kept as history

`docs/workflows/sdd-prd.md` and `docs/migrations/2026-07-05-harness-consolidation.md` describe the previous harness and remain unchanged as historical records.
