---
description: "Plan a feature, change, or decision the Fable way — producing a ready-for-sdd bundle for executable goals or a plan document for decisions."
agent: deep-planner
subtask: false
argument-hint: "[goal: feature, change, or problem to plan]"
---
You are running `/deep-plan` with raw arguments:
`$ARGUMENTS`

Delegate this workflow to the primary agent `deep-planner` using the exact raw arguments above.

Hard constraints:

- This is a plan-only workflow: do not modify production code, tests, or build files.
- Follow the `fable-planning` skill as the methodology contract for HOW you plan, regardless of output shape.
- Dual output by goal:
  - **Executable goal** (feature, change, bugfix) → a ready-for-sdd bundle following `docs/plan-handoff.md`, drafted by delegating to the sdd phase subagents (`sdd-proposal`, `sdd-spec`, `sdd-design`, `sdd-tasks`) per the agent's Bundle workflow.
  - **Decision / investigation** → a single Fable plan document following the `fable-planning` template.
- Allowed runtime write paths: `.ai/deep-planner/changes/**` (bundles) and `.ai/deep-planner/plans/**` (plan documents) only.
- The plan reasoning follows the `fable-planning` disciplines: Context (why + decisions), Design (approach, rejected alternatives, files, reused `path:symbol`), Edge Case Matrix, end-to-end Verification.
- The Edge Case Matrix is mandatory unless the plan states in one line why no edges are relevant (proportionality).
- Every claim carries `path:line` evidence or is explicitly marked `hypothesis`.
- Ask only decisions the repo cannot answer, one grouped round, each with a recommended answer.
