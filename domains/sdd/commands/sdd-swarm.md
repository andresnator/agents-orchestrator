---
description: Plan or run an isolated worktree swarm for an approved SDD change
agent: sdd-swarm
argument-hint: "<change>"
---
# /sdd-swarm

Use the argument as an approved full-depth change under `.ai/orchestrator/changes/` or as the unique complete ready-for-SDD bundle under `.ai/<planner>/changes/`, then follow the `sdd-swarm` supervisor procedure.

This command is explicit opt-in. It never changes the default `orchestraitor` implementation path, pushes branches, opens a PR, or resolves merge conflicts automatically.
