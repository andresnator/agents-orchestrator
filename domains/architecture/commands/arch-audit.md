---
description: "Read-only security and observability audit: dependency CVEs, runtime EOL, secrets heuristics, logging posture."
agent: sdlc-orchestrator
subtask: false
argument-hint: "[optional subpath or ecosystem]"
---
Raw arguments: `$ARGUMENTS`

Explicit SDLC route: `architecture / audit`. Route directly through `sdlc-orchestrator` to `architect` with `operation: audit`, preserving the raw arguments and constraints below; do not show the optional route menu.

Hard constraints:

- Load the `dependency-security-audit` skill and follow its checklist and output contract.
- Read-only commands only (`npm audit`, `mvn dependency:tree`, `pip-audit`, `osv-scanner`, …), each authorized through a primary-mediated `needs_input` receipt unless the request already authorizes it; never install tools, modify manifests or lockfiles, or run fix/upgrade commands.
- A denied or missing tool degrades to manifest inspection marked `method: manifest-fallback`, never a failure.
- Allowed write path: `.ai/architect/reports/**` only.
- Findings are severity-ranked with advisory IDs when known; secrets findings quote the location, never the value.
