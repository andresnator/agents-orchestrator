---
description: "Review code with oc-review: solo, dual, or defend. Add fix to fix the findings."
agent: orchestraitor
subtask: false
argument-hint: "[solo|dual|defend] [fix] [scope]"
---
Raw arguments: `$ARGUMENTS`

Load `oc-review`. The first argument selects the operation: `solo`, `dual`, or `defend`. If no operation is given, use `solo`. Do not ask which operation to use. The word `fix` asks for the fix step. The remaining arguments are the scope.
