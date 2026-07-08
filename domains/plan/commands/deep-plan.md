---
description: "Generate a Fable-style plan document for a feature, change, or technical decision."
agent: deep-planner
subtask: false
argument-hint: "[goal: feature, change, or problem to plan]"
---
You are running `/deep-plan` with raw arguments:
`$ARGUMENTS`

Delegate this workflow to the primary agent `deep-planner` using the exact raw arguments above.

Hard constraints:

- This is a plan-only workflow: do not modify production code, tests, or build files.
- Follow the `fable-planning` skill as the methodology contract.
- Allowed runtime write path: `.ai/deep-planner/plans/**` only — one plan document per goal.
- The plan follows the `fable-planning` template: Context (why + decisions), Design (approach, rejected alternatives, files, reused `path:symbol`), Edge Case Matrix, end-to-end Verification.
- The Edge Case Matrix is mandatory unless the plan states in one line why no edges are relevant (proportionality).
- Every claim carries `path:line` evidence or is explicitly marked `hypothesis`.
- Ask only decisions the repo cannot answer, one grouped round, each with a recommended answer.
