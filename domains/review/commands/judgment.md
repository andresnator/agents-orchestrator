---
description: Run the oc-judgment adversarial review protocol
agent: orchestraitor
subtask: false
argument-hint: "[light] [target files, feature, or scope]"
---
Raw arguments: `$ARGUMENTS`

Load `oc-review` and run `operation=judgment`. Leading `light` selects one solo sweep; otherwise use blind dual review. Ask directly when the target is missing; code changes require the protocol's explicit fix authorization. Never commit or push.
