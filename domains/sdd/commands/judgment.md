---
description: Run the judgment-day adversarial review protocol
agent: sdlc-orchestrator
subtask: false
argument-hint: "[light] [target files, feature, or scope]"
---
# /judgment

Raw arguments: `$ARGUMENTS`

Explicit SDLC route: `review / judgment`. Route directly through `sdlc-orchestrator` to `review-coordinator`, preserving the raw arguments and constraints below; do not show the optional route menu.

If the arguments start with `light` (or the request asks for a light/solo judgment), run the skill's Light Mode: one solo judge, automatic fix of CRITICALs only, no re-judge. Otherwise run the default dual protocol.

If no target is provided, `review-coordinator` returns `needs_input`; `sdlc-orchestrator` asks for the files, feature, or scope and resumes the same review child Task ID.
