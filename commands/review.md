---
description: "Run an oc-review operation: judgment, light, or defend."
agent: orchestraitor
subtask: false
argument-hint: "[judgment|light|defend] [scope]"
---
Raw arguments: `$ARGUMENTS`

Load `oc-review`. The first argument selects the operation: `judgment`, `light` (`operation=judgment` in light mode), or `defend`. Pass the remaining arguments as scope. If the operation is missing or unknown, ask one closed choice among `judgment`, `light`, and `defend`.
