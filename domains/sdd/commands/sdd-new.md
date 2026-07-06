---
description: "Start a T2 full-SDD change: triage, explore, propose, first gate"
agent: sdd-orchestrator
argument-hint: "[idea or change description]"
---
Start a new T2 SDD change for: $ARGUMENTS
1. Triage confirmation: check the request against the triage table (sdd-workflow skill). If it does not warrant T2 (no new feature, known area, no hot path, under 400 estimated lines), say so and recommend `/sdd-quick` or the `sdd-build` agent instead; only continue on T2 signals or explicit user insistence.
2. Derive a slug. Create `.arnes/changes/<slug>/` and `.arnes/changes/<slug>/handoffs/`, and write `state.yaml` with `change`, `tier: T2`, `phase: explore`, empty `gates` and `artifacts`, and timestamps.
3. Delegate `sdd-explore` for the change. On return, update state (`phase: propose`, record the handoff artifact).
4. Delegate `sdd-propose` with the explore handoff path. On return, update state and record `proposal.md`.
5. GATE: summarize the proposal from its handoff (intent, recommended approach, scope, blast radius) and ask via the `question` tool: approve / adjust / abort.
   - approve: record the gate decision in state.yaml, then stop and tell the user to continue with `/sdd-continue`.
   - adjust: relay the adjustment to a fresh `sdd-propose` run, then repeat the gate.
   - abort: record the decision and leave the change folder for manual cleanup.

Do not run spec, design, or any later phase in this command. Carry only envelopes and state in this thread; never paste artifact contents.
