---
description: "Read-only security and observability audit: dependency CVEs, runtime EOL, secrets heuristics, logging posture."
agent: architect
subtask: false
argument-hint: "[optional subpath or ecosystem]"
---
You are running `/arch-audit` with raw arguments:
`$ARGUMENTS`

Delegate this workflow to the primary agent `architect` in `audit` mode using the exact raw arguments above.

Hard constraints:

- Load the `dependency-security-audit` skill and follow its checklist and output contract.
- Read-only commands only (`npm audit`, `mvn dependency:tree`, `pip-audit`, `osv-scanner`, …), each ask-gated; never install tools, never modify manifests or lockfiles, never run fix/upgrade commands.
- A denied or missing tool degrades to manifest inspection marked `method: manifest-fallback`, never a failure.
- Allowed write path: `.ai/architect/reports/**` only.
- Findings are severity-ranked with advisory IDs when known; secrets findings quote the location, never the value.
