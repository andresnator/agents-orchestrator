---
description: Run the judgment-day adversarial review protocol
agent: review-coordinator
subtask: false
argument-hint: "[light] [target files, feature, or scope]"
---
Raw arguments: `$ARGUMENTS`

Run `operation=judgment`. Leading `light` selects one solo sweep; otherwise use blind dual review. Ask directly when the target is missing; code changes require the protocol's explicit fix authorization. Never commit or push.
