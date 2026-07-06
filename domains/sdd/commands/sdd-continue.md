---
description: "Advance the active SDD change to its next phase, stopping at the next gate"
agent: sdd-orchestrator
argument-hint: "[change slug (optional)]"
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: in-progress
---
Continue the SDD change: $ARGUMENTS
1. Resolve the change: use the change named in the arguments; if none, list `.arnes/changes/*/state.yaml` and pick the single active (non-archived) change — if several are active, ask the user which one via the `question` tool.
2. Read that change's `state.yaml` and determine the next step from the dependency chain:

   explore -> propose -> [gate] -> spec || design -> [gate] -> tasks -> apply -> verify -> review -> [gate] -> ship -> archive

3. Execute exactly the next step(s) — one phase, or the two parallel phases where the chain says so:
   - After the propose gate is approved: delegate `sdd-spec` and `sdd-design` in parallel, then hold the plan gate (approve / adjust / abort via the `question` tool) on their combined handoff summaries.
   - After the plan gate: delegate `sdd-tasks`, then `sdd-apply`, then `sdd-verify`, one per invocation of this command.
   - After verify: run review per the routing table (`sdd-review-quality` + `sdd-review-risk` in parallel; judgment-day protocol instead when the diff touches a hot path or exceeds 400 changed lines — load the `judgment-day` skill). Then hold the review gate.
   - After the review gate: ship via the `/sdd-ship` flow, then archive per the `sdd-workflow` state contract reference.
4. Update `state.yaml` after every transition (phase, artifacts, gate decisions, updated timestamp).
5. Stop at the next gate or at the end of the executed phase. Report the envelope summary and the next action.

If a phase returns `status: blocked`, relay its `questions[]` to the user via the `question` tool and re-delegate with the answers. Never skip a gate, never run phases past the next gate, never paste artifact contents into the thread.
