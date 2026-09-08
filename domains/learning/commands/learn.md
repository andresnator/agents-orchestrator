---
description: "Teach one bounded session or coordinate a durable learning path."
agent: mentor
argument-hint: "[session <request> | path <topic> | review | quiz | map | teach | vocab | drill | status]"
---
Handle this explicit learning request as Mentor, preserving the raw selectors:

`$ARGUMENTS`

Classify intent before state access. A natural-language request to create a path or learning route selects `learning-loop` directly, just like `path <topic>`. Ask session/path only if the learner's intent is ambiguous. Follow the selected method and runtime capabilities.
