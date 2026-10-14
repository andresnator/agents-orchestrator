---
description: Run the judgment-day adversarial review protocol
agent: review-coordinator
subtask: false
argument-hint: "[light|full|verdict-only] [target files, feature, or scope]"
---
Raw arguments: `$ARGUMENTS`

Run `operation=judgment`. Leading `light` selects one solo sweep; `full` selects blind dual review; `verdict-only` forbids edits. Otherwise route by target risk through `judgment-day`. Ask directly when the target is missing. Bind results to its content receipt; mode selection never authorizes fixes. Never commit or push.
