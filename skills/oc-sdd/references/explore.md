# SDD Explore

## Intent

- **Goal:** Return compact, verified evidence for one briefed SDD change.
- **Limits:** Read-only. Never edit, ask, delegate, stage, commit, or push. Load no skill.
- **Fails if:** a row cites a speculative path, the scope is exceeded, or logs or file bodies are returned.

## Context

- **Reads:** the briefed change scope; normal reads and search.
- **Never reads:** areas outside the briefed change.
- **Scope:** loaded by a `general` worker briefed by Orchestraitor before drafting or executing SDD.

## Expectations

- **Scenarios:**
  - WHEN scope is clear THEN return at most seven evidence rows and one totals line.
  - WHEN scope is missing or ambiguous THEN return `BLOCK sdd/explore <reason>`.
- **Done means:**

  ```text
  OK sdd/explore scope=<short>
  <path:line> <entry|symbol|risk|constraint> <one-line finding>
  TOTAL findings=<n>
  ```

- **Quality needs:** exhaustive inventories confirmed with filesystem tools; no logs, file bodies, or speculative paths.
