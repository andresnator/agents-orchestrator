# Refactor Domain

Risk-gated refactor planning and execution, Java refactor guidance, and reviewer agents.

Primary entries: `refactor-planner`, `refactor-executor`.

Commands: `refactor-plan`, `refactor-execute`.

```mermaid
graph TD
  command[refactor-plan] --> planner[refactor-planner]
  planner --> scope[scope-analyzer]
  scope --> risk[risk-assessor]
  risk --> reviewers[reviewers and safety workers]
  reviewers --> composer[refactor-openspec-composer]
  composer --> safety[refactor-safety-gate-reviewer]
  safety --> plan[17-section plan]
  plan --> executor[refactor-executor]
  executor --> report[execution report and commits]
  planner -. permission .-> boundary[.ia-refactor/plan only]
  reviewers -.-> skills[quality and safety skills]
```
