---
name: oc-build
description: "Execute a plan file to the end without stops. Trigger: ejecuta el plan, ejecuta <path>, run the plan, execute plan, build."
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: testing
---

# Build

## Intent

- **Goal:** Execute every task of one plan file, tick the progress in that file, and report the result.
- **Limits:** `orchestraitor` owns the plan file and all Git actions. A `worker` edits only the files of its brief. Changes stay in the working tree unless commits are requested (see "Delivery").
- **Fails if:**
  - A task is ticked `- [x]` but its check did not pass.
  - The run ends while a group that can start is not started.
  - A change to the plan is not written in `## Deviations`.

## Context

- **Reads:** the plan file, the files that the plan names, the project check commands, and `assets/worker-brief.md`.
- **Scope:** `ejecuta el plan <path>`, `ejecuta <path>`, `run the plan <path>`. Without a path, use the newest file in `.ai/plans/` and name it in the report. If no plan file exists, say so in one line.

## Expectations

- **Scenarios:**
  - WHEN the plan was executed before THEN skip `- [x]` tasks and try `- [!]` tasks again.
  - WHEN the plan is old or malformed THEN use it (see "Imperfect plan").
  - WHEN a task needs an action that the question rule of `global/AGENTS.md` protects THEN mark it `- [!]` with the reason `needs user approval` and continue with the other tasks.
- **Done means:** each task is `- [x]` or `- [!]`, each `Done means` item of the plan has a fresh result, and the final report is sent.

## Method

The plan is a guide. You can correct it. Make each decision yourself, write it down, and continue.

### Loop

1. Read the plan. A group is ready when each group in its `Depends on:` line is done.
2. Implement the ready groups:
   - One ready group, or ready groups that share files: implement them yourself, one at a time.
   - Two or more ready groups with disjoint `Files:`: send one brief per group to a `worker`, all in one message. Fill `assets/worker-brief.md` for each. Use the built-in `general` if `worker` is not available.
3. Run the check of each group yourself. The check is the narrowest command that proves the tasks of the group, for example the tests of the changed files. If there is no such command, read the diff against the tasks and note it.
4. If the check passes, change the tasks of the group to `- [x]` in the plan file.
5. If the check fails, or a worker returns `RESULT: failed`, fix the problem and run the check again. Do two retries maximum.
6. If the check still fails, change the tasks to `- [!]`, write the reason in `## Deviations`, and continue. A group that depends on a failed group also gets `- [!]` with the reason `depends on <n>`.
7. If the plan is wrong (a file does not exist, an approach is not possible), correct that group in the plan file, write the change in `## Deviations`, and continue.
8. Do steps 1 to 7 again until no group is ready.
9. Run each `Done means` item fresh. If an item fails, fix it one time and run it again.
10. Send the final report.

A worker can change a file outside its group. Keep the change if the check passes, and write it in `## Deviations`.

### Deviations

Add one line per event to `## Deviations`. Add the section if the plan does not have it.

```text
- Group 2: `src/auth/token.ts` does not exist. Used `src/auth/jwt.ts`.
- Group 3: failed after 2 retries. `npm test -- cart` gives a timeout in `cart.sync.test.ts`.
```

### Imperfect plan

Use the parts that exist. Write each gap as one line in `## Deviations`.

| Gap | Action |
| --- | --- |
| No groups, only a task list | Use the full list as one group. Do the tasks in order. |
| No `Files:` or `Depends on:` | Run the groups in order, one at a time. |
| Tasks without checkboxes | Add `- [ ]` to each task. |
| No `Done means` | Use the test and lint commands of the project. |
| No `Goal` | Use the title or the first paragraph. |
| Other fields or headings | Read them as notes. |

### Delivery

Commit only when the request or the plan line `Delivery: commits` asks for it. Then load `oc-commits` and commit each group after its check passes. In all other cases, leave the changes in the working tree.

### Final report

```text
Plan: .ai/plans/add-cart-sync.md
Done: 7 of 9 tasks
Failed: group 3 (timeout in `cart.sync.test.ts`)
Done means: `npm test` failed (2 tests), `npm run lint` ok
Assumptions: used the current retry limit of 3 for the sync client
Deviations: 2 (see the plan)
```
