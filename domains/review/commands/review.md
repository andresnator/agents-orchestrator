---
description: "Run an oc-review operation: judgment, light, or defend."
agent: orchestraitor
subtask: false
argument-hint: "[judgment|light|defend] [scope]"
---
Raw arguments: `$ARGUMENTS`

Load `oc-review`. The first argument selects the operation; pass the rest as scope. With no or an unknown operation, ask one closed choice among `judgment`, `light`, and `defend`.

- `judgment`: run `operation=judgment` as full blind dual review.
- `light`: run `operation=judgment` as one solo sweep.
- `defend`: run `operation=defend`; Socratic, read-only, one design decision and user defense at a time; never fix.

Ask directly when the target is missing (for `defend`, when no scope or working-tree diff exists). Code changes require the protocol's explicit fix authorization. Never commit or push.
