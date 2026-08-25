---
description: Route documentation work to the right skill
argument-hint: "[what to document]"
---
aw arguments: `$ARGUMENTS`

Select the single most specific documentation skill whose activation contract matches the request, then load and follow it. Ask one question only when missing or ambiguous intent would materially change the artifact. If no exact skill matches, use `cognitive-doc-design` for general documentation; redirect non-documentation work.

The selected skill owns its workflow, writes, and output. Do not route through another command or restate or override the skill contract.
