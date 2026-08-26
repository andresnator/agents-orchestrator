---
description: Switch Caveman response compression for this session and its subagents
argument-hint: "[lite|full|ultra|wenyan]"
---
Raw arguments: `$ARGUMENTS`

The `caveman-mode` plugin applies the selection to this session tree. Empty arguments select `lite`. Accept exactly `lite`, `full`, `ultra`, or `wenyan`; for anything else, keep the current level and reply with the valid command syntax. Acknowledge a valid selection in one short sentence using the selected style.

`stop caveman` and `normal mode` switch this session subtree to normal prose.
