---
description: "Read-only dependency security and observability audit."
agent: sdlc-orchestrator
subtask: false
argument-hint: "[optional subpath or ecosystem]"
---
Raw arguments: `$ARGUMENTS`

Route `architecture/audit` to `architect`. Audit commands require primary-mediated authorization; never install, fix, upgrade, or edit manifests. Write only `.ai/architect/reports/**`; missing tools use manifest fallback.
