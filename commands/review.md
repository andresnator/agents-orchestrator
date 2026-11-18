---
description: "Review code with oc-review: solo, dual, or defend. Add fix to fix the findings."
agent: orchestraitor
subtask: false
argument-hint: "[solo|dual|defend] [fix] [target]"
---
Raw arguments: `$ARGUMENTS`

Load `oc-review`. The operation is `solo`, `dual`, or `defend`. `light` means `solo` and `judgment` means `dual`. If no operation is given, use `solo`. The word `fix`, `arregla`, or `corrige` asks for the fix step. All other arguments are the target. If there is no target, review the working-tree diff.
