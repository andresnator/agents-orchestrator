---
description: "Validate project state (toolchain, architecture style, gaps) and produce an evidence-backed ranked issue shortlist."
agent: architect
subtask: false
argument-hint: "[optional subpath or focus]"
---
You are running `/arch-review` with raw arguments:
`$ARGUMENTS`

Delegate this workflow to the primary agent `architect` in `review` mode using the exact raw arguments above.

Hard constraints:

- Load `architecture-state` for the verified project state and gap analysis, and `repo-issues` for the adversarially-filtered issue shortlist.
- Allowed write path: `.ai/architect/reports/**` only.
- Every claim has `file:line` evidence or is marked hypothesis; README-only claims are `aspirational`.
- Gaps propose fitness functions matched to the detected toolchain; the shortlist keeps only FIX/CONDITIONAL items and reroutes code-level findings to `/refactor-plan`.
- Run parallel `arch-analyzer` fan-out per the lens catalog; a missing lens skill is reported skipped, never failed.
