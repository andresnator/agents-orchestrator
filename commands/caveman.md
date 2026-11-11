---
description: Save Caveman response compression globally for all primary and subagent sessions
argument-hint: "[lite|full|ultra|wenyan]"
---
Raw arguments: `$ARGUMENTS`

The `caveman-mode` plugin saves one global selection for all existing and new primary and subagent sessions sharing the same OpenCode configuration directory. Each uses the current selection on its next response, including across processes and restarts. With no saved selection, the fallback is `lite`.

Empty arguments select `lite`. Accept `lite`, `full`, `ultra`, or `wenyan` after trimming whitespace and ignoring case. Invalid arguments leave the saved selection unchanged; show `Usage: /caveman [lite|full|ultra|wenyan]`. Acknowledge a successful selection in one short sentence using the selected style and naming its global scope. If the plugin reports a state error, do not claim the selection succeeded or silently replace the saved state.

Send `stop caveman` or `normal mode` as a standalone message to save `off` globally. It persists across restarts until another level is selected, just like every other level; `/caveman off` is not valid syntax.
