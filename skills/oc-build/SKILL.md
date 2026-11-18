---
name: oc-build
description: "Execute a plan file to the end without stops; resume it later. Trigger: ejecuta el plan, ejecuta <path>, retoma el plan, run the plan, execute plan."
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: testing
---

# Build

## Intent

- **Goal:** Execute every task of one plan file, tick the progress in that file, and report the result.
- **Limits:** `orchestraitor` owns the plan file and all Git actions. A `worker` gets one group and does not edit the plan file. Changes stay in the working tree unless commits are requested (see "Delivery").
- **Fails if:**
  - A task is ticked `- [x]` but its check did not pass.
  - The run stops or asks a question while a group is ready.
  - A change to the plan is not written in `## Deviations`.

## Context

- **Reads:** the plan file, the files that the plan names, the project check commands, and `assets/worker-brief.md`.
- **Scope:** `ejecuta el plan <path>`, `ejecuta <path>`, `run the plan <path>`. The same request on an executed plan resumes it.
  - No path: use the newest file in `.ai/plans/`. Say which file in one line, then start.
  - The path does not exist: use the file with the same name in `.ai/plans/`.
  - No plan file found: say so in one line and end.

## Expectations

- **Scenarios:**
  - WHEN the plan was executed before THEN skip `- [x]` tasks and try `- [!]` tasks again.
  - WHEN the plan is old or malformed THEN use it (see "Imperfect plan").
  - WHEN a task needs an action that the question rule of `global/AGENTS.md` protects, and the current request does not ask for that action, THEN mark the task `- [!]`, add `(needs the user)` to the end of its line, do the other tasks, and name it in the report.
- **Done means:** each task is `- [x]` or `- [!]`, each `Done means` item of the plan has a fresh result, and the final report is sent.

## Method

The plan is a guide. You can correct it. Make each decision yourself, write it down, and continue. Do not ask the user during the run.

### Loop

1. Read the plan. A group is done when all its tasks are `- [x]`; a task with `(needs the user)` does not count. A group is ready when it is not done, you did not try it in this run, and each group in its `Depends on:` line is done.
2. Compare each ready group with the repository. If the plan is wrong (a file does not exist, an approach is not possible), correct that group in the plan file, write the change in `## Deviations`, and continue.
3. Make the parallel set: take the ready groups in plan order, and add a group when its `Files:` share no path with the groups in the set. A path in a listed directory is a shared path. A group without `Files:` does not go in the set.
4. Implement the tasks that are not `- [x]`:
   - The set has two or more groups: fill `assets/worker-brief.md` for each group and send the briefs to `worker` agents, all in one message. Use the built-in `general` if `worker` is not available.
   - The set has one group or is empty: implement the first ready group yourself.
   - The other ready groups stay ready for the next pass.
5. Run the check of each group yourself, also after `RESULT: ok`. The check is the narrowest command that proves the tasks of the group, for example the tests of the changed files. Put the same command in the brief. If there is no such command, read the diff against the tasks and note it.
6. If the check passes, change the tasks of the group to `- [x]` in the plan file. Copy worker `NOTES` that are not `none` to `## Deviations`.
7. If the check fails, fix the problem yourself and run the check again. Do two retries maximum. A worker reply with `RESULT: failed`, or without the three return lines, is a failed check: read the diff of the group, complete its tasks yourself, and run the check.
8. If the check still fails after two retries, change the tasks of the group to `- [!]`, write the reason in `## Deviations`, and continue.
9. Do steps 1 to 8 again until no group is ready. Then change each task that is still `- [ ]` to `- [!]` with the reason `depends on <n>`.
10. Run each `Done means` item fresh. If an item fails, fix it one time and run it again. Report the last result.
11. Send the final report.

A worker can change a file that is not in its `Files`. Keep the change if the check passes, and write it in `## Deviations`.

### Deviations

Add one line per event to `## Deviations`. Add the section if the plan does not have it.

```text
- Group 2: `src/auth/token.ts` does not exist. Used `src/auth/jwt.ts`.
- Group 3: failed after 2 retries. `npm test -- cart` gives a timeout in `cart.sync.test.ts`.
- Group 4: depends on 3.
```

### Imperfect plan

Use the parts that exist. Write each gap as one line in `## Deviations`.

| Gap | Action |
| --- | --- |
| No groups, only a task list | Use the full list as one group. Do the tasks in order. |
| No `Files:` or `Depends on:` | Run the groups in order, one at a time. |
| `Depends on:` names a group that does not exist, or two groups depend on each other | Ignore that dependency. |
| Tasks without checkboxes | Add `- [ ]` to each task. |
| No `Done means` | Use the test and lint commands of the project. |
| No `Goal` | Use the title or the first paragraph. |
| Other fields or headings | Read them as notes. |

### Delivery

Commit only when the request or the plan line `Delivery: commits` asks for it. Then load `oc-commits` and commit each group after its check passes. In all other cases, leave the changes in the working tree.

### Final report

```text
Plan: .ai/plans/add-cart-sync.md
Done: 6 of 9 tasks
Failed: group 3 (timeout in `cart.sync.test.ts`), group 4 (depends on 3)
Needs the user: group 2 task 3, push the release tag
Done means: `npm test` failed (2 tests), `npm run lint` ok
Assumptions: used the current retry limit of 3 for the sync client
Deviations: 3 (see the plan)
```
