---
description: "Generate or refresh compact C4-lite Mermaid architecture docs (context, containers, key flows) in the project's doc folder."
agent: sdlc-orchestrator
subtask: false
argument-hint: "[optional subpath or focus]"
---
Raw arguments: `$ARGUMENTS`

Explicit SDLC route: `architecture / map`. Route directly through `sdlc-orchestrator` to `architect` with `operation: map`, preserving the raw arguments and constraints below; do not show the optional route menu.

Hard constraints:

- Load the `architecture-map` skill and follow its doc set, budgets, and drift-refresh rules.
- Allowed write path: `<docfolder>/architecture/**` only (existing `docs/`, else `doc/`, else create `doc/`).
- C4-lite levels 1-2 only; every diagram element has code evidence or a `hypothesis` mark.
- Idempotent: when the doc set exists, diff, refresh in place, and report a drift summary instead of rewriting.
- Architecture-level only; no code, test, or build-file edits.
