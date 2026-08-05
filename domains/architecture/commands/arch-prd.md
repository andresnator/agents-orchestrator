---
description: "Reverse-engineer a PRD from the codebase via the prd/prd-light skills, including a Mermaid flow diagram."
agent: sdlc-orchestrator
subtask: false
argument-hint: "[optional product/feature scope]"
---
Raw arguments: `$ARGUMENTS`

Explicit SDLC route: `architecture / prd`. Route directly through `sdlc-orchestrator` to `architect` with `operation: prd`, preserving the raw arguments and constraints below; do not show the optional route menu.

Hard constraints:

- Reconstruct product behavior from code evidence (routes, entrypoints, domain models, tests); unknown product intent is asked, never invented.
- Draft with the `prd-light` skill by default; use `prd` only when the user asks for the rigorous version.
- Include one Mermaid flow diagram of the core user flow.
- Suggested output path: `<docfolder>/architecture/PRD-<name>.md`; confirm the path with the user before writing.
- Allowed write path: `<docfolder>/architecture/**` only; no code, test, or build-file edits.
