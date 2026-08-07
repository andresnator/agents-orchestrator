---
description: Run the judgment-day adversarial review protocol
agent: sdlc-orchestrator
subtask: false
argument-hint: "[light] [target files, feature, or scope]"
---
Raw arguments: `$ARGUMENTS`

Route `review/judgment` to `review-coordinator`. Leading `light` selects one solo sweep; otherwise use blind dual review. Missing target returns `ASK`; code changes require the protocol's explicit fix authorization. Never commit or push.
