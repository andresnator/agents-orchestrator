---
name: oc-review
description: "Code review with scout judges: solo, dual, or defend. Fixes findings only on the word fix. Trigger: review, revisar, code review, dual review, defend."
license: Apache-2.0
metadata:
  author: gentleman-programming
  adapted_by: andresnator
  source: gentleman-programming/sdd-agent-team
  version: "4.0.2"
  status: testing
---
# Review

## Intent

- **Goal:** Give one review verdict for a target, with evidence for each finding. Fix findings only when the request tells you to fix: the word `fix`, `arregla`, or `corrige` as an instruction. These are the `fix` word in the steps below.
- **Limits:** The request decides the operation and the fix. Do not ask the user to select them. Do not stage, commit, or push. `defend` never edits.
- **Fails if:** a file changes when the request has no `fix` word, a finding has no `path:line`, or the report has no verdict.

## Context

- **Reads:** the target, and 0 to 5 short project rules from the `AGENTS.md` and `standards/` of the project, when they exist.
- **Scope:** `/review` or a review request. Judges are `scout` subagents. The fixer is a `worker` subagent. If one is not available, use `general`.

## Expectations

| Operation | Behavior |
| --- | --- |
| `solo` (default; also `light`) | One judge with lens `solo`. |
| `dual` (also `judgment`) | Two judges in parallel: lens `a` and lens `b`. |
| `defend` | The user defends the design decisions. Read-only. |

- **Scenarios:**
  - WHEN the request names no operation THEN use `solo`.
  - WHEN the request names no target THEN review the working-tree diff: `git diff HEAD` and the untracked files.
  - WHEN there is no target and no diff THEN say that there is nothing to review, and stop.
  - WHEN a judge reply does not follow the format THEN send the same brief one more time. If the second reply is also wrong, add what it found as rows with status `unverified`. Use severity `warning` when it gives none.
  - WHEN the request has `defend` and `fix` THEN ignore `fix` and say so in the report.
- **Done means:** the report starts with `APPROVED`, `FINDINGS`, or `FIXED`. Then it shows the ledger from `assets/output-formats.md`, the check result when a fix ran, and the assumptions. Use the language of the user. Do not paste logs or diffs.

## Method

### `solo` and `dual`

1. Find the target. Collect the project rules.
2. Fill `assets/judge-brief.md` and send it: one brief for `solo`, two briefs at the same time for `dual`. A judge brief never contains the reply of another judge.
3. Build the ledger. In `dual`, two findings are the same when they show the same problem at the same place. Merge them into one row with source `both` (confirmed) and keep the higher severity.
4. If the request has no `fix` word, report the verdict and stop.
5. If the request has `fix`, send one `worker` brief with all `open` rows of severity `critical` or `warning`. Do not send `unverified` rows. If there is no such row, report the verdict now.
6. Mark a sent row `fixed` when the `worker` changed its file and `NOTES` does not reject it. All other rows stay `open`. Then run the project checks (tests and lint) one time. If the project has no check command, say so and continue.
7. In `dual` only, send one more judge brief with lens `solo`, the changed files as target, and the fixed rows in `Recheck`. Each finding in the reply is an `open` row. Set a returned `Recheck` row to `open` again, and add a new row for a new finding.
8. Report the verdict. There is one fix round only. Rows that stay `open` go into the report.

### Fix brief

Send this text to the `worker`. The `worker` loads no skill.

```text
Fix these review findings. Change only the lines that each fix needs.
Findings:
<one finding line per row>
Rules: <0 to 5 project rules, or none>
Check: <command, or none>
Do not use Git. Do not ask questions. If a finding is not clear, make the smallest safe fix and report it.
If a finding is wrong, do not change the code, and say why in NOTES.
Return exactly:
RESULT: ok | failed
FILES: <csv of changed paths>
NOTES: <assumptions and problems, or none>
```

### `defend`

1. Read the target. List its design decisions, the most important first.
2. Show one decision at a time, with `path:line`. Ask the user to defend it, and give the strongest defense that the evidence supports as `Recommendation: ...`.
3. If the defense is sound, accept it. If it is weak, challenge it one time with evidence.
4. If the second defense is also weak, record a finding with source `defend`.
5. After the last decision, or when the user stops, report `APPROVED` or `FINDINGS` with the ledger.

Review protocol adapted from `gentleman-programming/sdd-agent-team` (Apache-2.0).
