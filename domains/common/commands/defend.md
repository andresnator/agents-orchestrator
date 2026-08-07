---
description: Socratic review where the user defends the design decisions in their code
agent: sdlc-orchestrator
subtask: false
argument-hint: "[diff, branch, files, or scope to defend]"
---
Raw arguments: `$ARGUMENTS`

Route `review/defend` to `review-coordinator`. Review read-only, one design decision and user defense at a time; never fix, commit, or push. If no scope or working-tree diff exists, return one blocking question.
