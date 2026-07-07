---
description: "Generate or refresh compact C4-lite Mermaid architecture docs (context, containers, key flows) in the project's doc folder."
agent: architect
subtask: false
argument-hint: "[optional subpath or focus]"
---
You are running `/arch-map` with raw arguments:
`$ARGUMENTS`

Delegate this workflow to the primary agent `architect` in `map` mode using the exact raw arguments above.

Hard constraints:

- Load the `architecture-map` skill and follow its doc set, budgets, and drift-refresh rules.
- Allowed write path: `<docfolder>/architecture/**` only (existing `docs/`, else `doc/`, else create `doc/`).
- C4-lite levels 1-2 only; every diagram element has code evidence or a `hypothesis` mark.
- Idempotent: when the doc set exists, diff, refresh in place, and report a drift summary instead of rewriting.
- Architecture-level only; no code, test, or build-file edits.
