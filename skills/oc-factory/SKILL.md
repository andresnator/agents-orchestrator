---
name: oc-factory
description: "Run independent tasks in parallel worktrees. Trigger: factory, software factory, tareas en paralelo, parallel tasks, delegate tasks."
license: MIT
metadata:
  author: andresnator
  version: 1.0.0
  status: testing
---
# Software factory

## Intent

- **Goal:** Give several independent tasks to background workers and return to the user at once.
- **Limits:** `scripts/factory.sh` owns all state, worktrees, branches, and processes. Do not edit `.ai/factory/` by hand. Run `merge` and `drop` only when the user asks. Run `merge` without a request only if the user said `automerge`.
- **Fails if:** you wait for a worker; two running tasks edit the same files; a brief needs this conversation to make sense.

## Context

- **Reads:** the user request, the repository files that you need to write good briefs, and the output of `scripts/factory.sh`.
- **Scope:** several independent tasks at the same time, `factory`, `/factory`, a request for the state of the tasks; inside a Git repository with one commit or more.

## Expectations

- **Scenarios:**
  - WHEN a task is `needs-input` THEN show its question. The other tasks continue. Run `answer` when the user replies.
  - WHEN `merge` reports `conflict` THEN tell the user. The main working tree is clean. Offer `answer <id> "merge main and fix the conflict"`, or `drop`.
- **Done means:** each task is added and started, and the user has the ids and the next command (`/factory status`).

## Method

The script is in the directory of this skill. Use the base directory that the skill loader reports:
`bash <skill base directory>/scripts/factory.sh <command>`. Run it from inside the repository of the user.

### Start work

1. Split the request into independent tasks. If two tasks edit the same files, make them one task. If you cannot join them, write the order in the two briefs and start the second after the merge of the first.
2. Give each task a short kebab-case id, for example `fix-login`.
3. Write one brief for each task. The worker sees only the brief, so put all the necessary facts in it.
4. Run `add <id> -` for each brief, with the brief on standard input.
5. Run `start` one time. Use `--max N` if the user gave a limit.
6. Tell the user the ids, then stop. Do not wait. Do not run `status` in a loop.

Brief format:

```markdown
# <verb-led outcome>

Goal: <one or two sentences>
Files: <paths or directories where the change probably is>
Done means:
- <command or check that the worker can run>
Notes: <optional: limits, decisions, order with other tasks>
```

The script adds the worker rules and the `FACTORY:` result line to each brief. Do not write them in the brief.

### Commands

| Command | Use |
| --- | --- |
| `add <id> <brief-file\|->` | Store a brief. State `queued`. |
| `start [<id>...] [--max N]` | Start queued tasks in the background. Also starts a `failed` task again. |
| `status` | Print the board: state, commits, and question or reason for each task. |
| `answer <id> <text>` | Add the answer to the brief and start the task again. |
| `logs <id> [lines]` | Print the end of the log. Use it for a `failed` task. |
| `merge <id>` | Merge a `done` task into the current branch. Remove its worktree and branch. |
| `drop <id>` | Stop the task. Remove its worktree, branch, and state. |

### Show the state

Run `status` and show the table as it is. Below the table, write one line for each task that needs the user:

- `needs-input`: the question, and `/factory answer <id> <text>`.
- `done`: `/factory merge <id>`.
- `failed`: the reason, and `/factory logs <id>`.
- `conflict`: the files in conflict.

If the script prints `runner not found`, tell the user to install OpenCode or to set `FACTORY_RUNNER`.
