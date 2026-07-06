# Refactor Domain

Refactor planning, risk-gated legacy safety analysis, Java refactor guidance, reviewer agents, and the OpenCode write-guard plugin.

Primary entries: `refactor-planner`.

Commands: `refactor-plan`.

```mermaid
graph TD
  command[refactor-plan] --> planner[refactor-planner]
  planner --> scope[scope-analyzer]
  scope --> risk[risk-assessor]
  risk --> reviewers[reviewers and safety workers]
  reviewers --> composer[refactor-openspec-composer]
  composer --> safety[refactor-safety-gate-reviewer]
  safety --> plan[17-section plan]
  reviewers -.-> skills[quality and safety skills]
```
