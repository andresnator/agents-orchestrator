---
description: "T1 quick-change pipeline: explore-lite, apply, advisory review"
agent: sdd-orchestrator
argument-hint: "[task description]"
---
Run the T1 quick pipeline for: $ARGUMENTS
1. Derive a short slug from the task description. Create or update `.arnes/changes/<slug>/state.yaml` with `tier: T1`, `phase: explore` (schema in the `sdd-workflow` skill; the sdd-orchestrator owns this file).
2. Delegate `sdd-explore` with instructions to run exactly one `codegraph_explore` query (no file crawling) and write `.arnes/changes/<slug>/handoffs/explore.md`.
3. Update state to `phase: apply`. Delegate `sdd-apply` with the task description and the explore handoff path. For a single work unit no tasks.md is needed; if the work splits into more than one unit, instruct sdd-apply to keep a minimal checklist in `.arnes/changes/<slug>/tasks.md`.
4. Update state to `phase: review`. Delegate `sdd-review-quality` on the resulting diff. Its findings are advisory: report them, do not block.
5. Report to the user: the apply envelope summary, the review findings summary, and artifact paths.
6. Escalation check: if any envelope shows the scope exceeded T1 bounds (more than 3 files, hot path touched, behavior change beyond the ask), use the `question` tool to propose escalation to T2 (options: escalate to /sdd-new inheriting the exploration / stay in T1 / abort).

Carry only envelopes and state in this thread; never paste file contents.
