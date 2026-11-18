---
name: oc-plan
description: "Trigger: plan, light plan, plan rápido, deep plan, plan profundo, wayfinder, explore an idea. Writes one short executable plan or one discovery."
license: MIT
metadata:
  author: andresnator
  version: "6.0.0"
  status: testing
---

# Plan

## Intent

- **Goal:** One saved plan that `ejecuta el plan <path>` can run, or one Wayfinder discovery.
- **Limits:** Write only the plan or discovery file under `.ai/`. Leave code changes, builds, tests, and Git to the executor.
- **Fails if:**
  - the plan has no `Goal`, no `Done means`, or no `Tasks`;
  - a `Done means` item is not a command or an observable check;
  - a file outside `.ai/` changes.

## Context

- **Reads:** the request; the repository files that change the plan; `references/deep.md` in deep mode only.
- **Scope:**

  | Mode | Triggers | Use for |
  | --- | --- | --- |
  | light (default) | `plan`, `light plan`, `quick plan`, `plan rápido` | local work that one session can verify |
  | deep | `deep plan`, `plan profundo`, `evidence-first plan`, `wayfinder`, `explore an idea`, `convert this discovery into a plan` | large or risky work; ideas with an undecided destination |
  | format | other skills that write a plan (`oc-grill`, `oc-arch`, `oc-build`) | "Plan format" below only |

## Expectations

- **Scenarios:**
  - WHEN the mode is not stated THEN use light. Use deep, and say so in one line, only when the work restructures code that several callers use, breaks an existing public contract, or migrates data.
  - WHEN a fact is unknown THEN find it in the repository.
  - WHEN only the user can decide a detail THEN pick the most reasonable default, continue, and write it in `## Notes` as `Assumption: <default> (<reason>)`.
  - WHEN the choice controls a task that cannot be undone (delete user data, migrate real data, rewrite history) THEN ask one question before you write the plan.
  - WHEN the user gives the exact path of an existing plan THEN update that file and keep its ticked tasks.
- **Done means:** the file is saved. The reply gives the plan (light) or a short summary (deep), the assumptions, and the last line `ejecuta el plan <path>`.

## Method

### Light mode

1. Read the few files that change the plan. Do the work yourself, without subagents.
2. Write the plan as "Plan format" below tells. Write only what changes execution.
3. Save it, then show it in chat.

### Deep mode

Read `references/deep.md` and follow it.

### Plan format

All planners write this shape. `oc-build` reads it and ticks the tasks. The example shows the full shape; `assets/plan-template.md` is the blank copy.

- **Path:** `.ai/plans/<slug>.md`. The slug is kebab-case, from the goal. Create the folder if it is missing. If the path exists already, add a numeric suffix (`-2`).
- **Done means:** each item is a command with its expected result, or a check that a person can see.
- **Groups:** a group is one goal with its files. Number the groups `1`, `2`, `3`. `Files:` gives the paths that the group creates or changes, with commas between them. `Depends on:` gives `none` or group numbers (`1, 2`).
- **Parallel work:** `oc-build` runs groups at the same time when their dependencies are done and their `Files:` share no path. Split the work this way when it is possible, and give a group only the dependencies it needs.
- **Tasks:** each task is one small change with a result that a check can show. Start it with a verb. Put the test task in the same group as its code. The project checks must pass at the end of each group.
- **Notes:** limits, decisions, risks, assumptions, evidence as `path:line`, and behavior as `WHEN <condition> THEN <result>`. Mark a fact you did not verify as `hypothesis`. Omit the section when it has no content.
- **Deviations:** keep the heading with no content. The executor writes there.
- **Delivery:** write the line `Delivery: commits` directly below the title only when the user asked for commits. Git steps are not tasks.

Example:

```markdown
# Plan: Add retry to the export job

## Goal

The export job retries a failed upload three times before it reports an error.

## Done means

- `npm test -- export` passes.
- A failed upload shows three attempts in the log.

## Tasks

### 1. Retry logic

Files: src/export/upload.ts, src/export/upload.test.ts
Depends on: none

- [ ] Add `retryUpload` with three attempts and a 2 s wait.
- [ ] Add a test: two failures, then success.

### 2. Operator docs

Files: docs/export.md
Depends on: none

- [ ] Document the retry count.

## Notes

- Assumption: three attempts (same as `src/import/fetch.ts:41`).
- WHEN all attempts fail THEN the job exits with code 1.

## Deviations
```
