---
description: "Generate a legacy-focused safety plan centered on characterization coverage, seams, and rollback."
agent: legacy-safety-planner
subtask: false
argument-hint: "[target path] [mode=smoke]"
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "1.0.0"
  status: in-progress
---
You are running `/legacy-safety-plan` with raw arguments:
`$ARGUMENTS`

Delegate this workflow to the primary agent `legacy-safety-planner` using the exact raw arguments above.

Hard constraints:

- This is a plan-only workflow: do not modify production code.
- Optional `mode=smoke` token or `--smoke` flag: runs the fast harness-validation path (stub plan, no worker/reviewer fan-out). Strip it before parsing the target.
- The first non-flag argument is the legacy target.
- Allowed runtime write path: `.ia-refactor/plan/YYYYMMDD/<target-name>-legacy-safety.md` only.
- Forbidden paths: `src/**`, `app/**`, `lib/**`, `domain/**`, `infrastructure/**`, `pom.xml`, `build.gradle`, `settings.gradle`, `package.json`.
- Focus on characterization-test coverage, seams, risk containment, and rollback, not broad cleanup.
- Keep behavior-changing ideas out of executable backlog work.
- Every finding must have file/line/symbol evidence, or be explicitly marked as a hypothesis.
- Tasks must be small, ordered, verifiable, reversible, and safe for incremental execution.
