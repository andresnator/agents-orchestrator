# Refactor Domain

Refactor planning, legacy safety planning, Java refactor guidance, reviewer agents, and the OpenCode write-guard plugin.

Primary entries: `refactorch`, `refactor-planner`, `legacy-safety-planner`.

Commands: `refactor-plan`, `legacy-safety-plan`.

```mermaid
graph TD
  commands[Refactor commands] --> planners[primary planners]
  planners --> reviewers[reviewer subagents]
  reviewers --> composer[refactor-openspec-composer]
  composer --> safety[refactor-safety-gate-reviewer]
  planners --> plugin[write-guard plugin]
  reviewers -.-> common[common quality skills]
```
