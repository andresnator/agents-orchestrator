---
description: "Show a compact status table for all SDD changes, from state files only"
agent: sdd-orchestrator
subtask: true
argument-hint: "[change slug (optional)]"
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: in-progress
---
Report SDD harness status. Read-only; delegate nothing; modify nothing.
1. Read every `.arnes/changes/*/state.yaml` in the project (bash: list the glob, then read each file). If none exist, report "No active changes" and stop.
2. Print one compact table:

   | Change | Tier | Phase | Last gate decision | Next action |
   |---|---|---|---|---|

   - Last gate decision: the most recent entry in `gates` as `<gate>: <decision>` or `-` if none.
   - Next action: derived from tier and phase against the chain explore -> propose -> [gate] -> spec || design -> [gate] -> tasks -> apply -> verify -> review -> [gate] -> ship -> archive (for T1: explore -> apply -> review). Phrase it as the command to run, usually `/sdd-continue <change>` or `/sdd-quick`.
3. If a state.yaml is malformed, show the change with phase `unreadable` instead of failing the whole table.

Output only the table plus at most two lines of commentary.
