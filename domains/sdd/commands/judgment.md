---
description: Run the judgment-day adversarial review protocol
argument-hint: "[light] [target files, feature, or scope]"
---
# /judgment

Load and follow the `judgment-day` skill for the requested target.

If the arguments start with `light` (or the request asks for a light/solo judgment), run the skill's Light Mode: one solo judge, automatic fix of CRITICALs only, no re-judge. Otherwise run the default dual protocol.

If no target is provided, ask for the files, feature, or scope to review before starting the protocol.
