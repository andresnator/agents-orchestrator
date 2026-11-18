---
description: "Run tasks in parallel with oc-factory: start, status, answer, logs, merge, or drop."
agent: orchestraitor
subtask: false
argument-hint: "[status|answer <id> <text>|logs <id>|merge <id>|drop <id>|<tasks to start>]"
---
Raw arguments: `$ARGUMENTS`

Load `oc-factory`. If there are no arguments, run `status` and show the board. If the first argument is `status`, `answer`, `logs`, `merge`, or `drop`, run that command with the remaining arguments. For all other text, use the arguments as the request: split it into tasks, start them, and return at once.
