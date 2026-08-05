---
description: "Validate project state (toolchain, architecture style, gaps) and produce an evidence-backed ranked issue shortlist."
agent: sdlc-orchestrator
subtask: false
argument-hint: "[optional subpath or focus]"
---
Raw arguments: `$ARGUMENTS`

Explicit SDLC route: `architecture / review`. Route directly through `sdlc-orchestrator` to `architect` with `operation: review`, preserving the raw arguments and constraints below; do not show the optional route menu.

Hard constraints:

- Load `architecture-state` for the verified project state and gap analysis, and `repo-issues` for the adversarially-filtered issue shortlist.
- Allowed write path: `.ai/architect/reports/**` only.
- Every claim has `file:line` evidence or is marked hypothesis; README-only claims are `aspirational`.
- Gaps propose fitness functions matched to the detected toolchain; the shortlist keeps only FIX/CONDITIONAL items and reroutes code-level findings to `/refactor-plan`.
- Run parallel `arch-analyzer` fan-out per the lens catalog; a missing lens skill is reported skipped, never failed.
