# Software Factory

The factory runs independent tasks at the same time. Each task has its own Git worktree, branch, and background worker. You continue to work while the tasks run.

## Quick path

1. Open OpenCode in your repository. The repository must have one commit or more.
2. Give the tasks: `/factory add the CSV export; fix the login timeout`.
3. Read the task ids in the reply. The tasks run in the background.
4. Run `/factory status` to see the board.
5. Run `/factory merge <id>` for each `done` task.

A request in normal language also works: "usa factory para hacer estas dos tareas en paralelo: ...".

## Commands

| Command | Result |
| --- | --- |
| `/factory <tasks>` | Writes one brief for each task, starts the tasks, and returns at once. |
| `/factory` or `/factory status` | Shows the board. |
| `/factory answer <id> <text>` | Adds your answer to the brief and starts the task again. |
| `/factory logs <id>` | Shows the end of the task log. |
| `/factory merge <id>` | Merges the task branch into your current branch. Removes the worktree and the branch. |
| `/factory drop <id>` | Stops the task. Removes the worktree, the branch, and the state. |

The agent runs `merge` and `drop` only when you ask. If your request contains `automerge`, the agent merges each `done` task without a new request.

## Task states

| State | Meaning | Your next step |
| --- | --- | --- |
| `queued` | The brief is stored. The task did not start. | None. `start` runs it. |
| `running` | The worker is at work. | Wait, or do other work. |
| `done` | The worker committed its work on `factory/<id>`. | `/factory merge <id>` |
| `needs-input` | The worker has a question. The other tasks continue. | `/factory answer <id> <text>` |
| `failed` | The worker stopped with an error. | `/factory logs <id>`, then start again or `drop`. |
| `conflict` | The merge had a conflict. The script aborted the merge. | Ask the task to merge your branch and fix the conflict, or `drop`. |
| `merged` | The work is in your branch. | None. |

## Rules

- Give tasks that do not edit the same files. The agent joins two tasks that overlap.
- A worker sees only its brief. It does not see your conversation.
- A worker commits on its branch. It never pushes.
- Work can be lost. `drop` deletes commits that are not merged. Merge the task first if you want its work.
- Do not edit `.ai/factory/` by hand. The script owns it.
- Run the commands from the main working tree, not from a factory worktree.

## Files

| Path | Content |
| --- | --- |
| `.ai/factory/board.md` | The board. `status` writes it. |
| `.ai/factory/tasks/<id>.md` | The brief of each task. |
| `.ai/factory/logs/<id>.log` | The output of each worker. |
| `<repo-parent>/.<repo-name>-factory/<id>` | The worktree of each task. |

The script adds `.ai/` to `.git/info/exclude` if Git does not ignore it.

## Use the script directly

The script is `skills/oc-factory/scripts/factory.sh`. After the install it is at `~/.config/opencode/skills/oc-factory/scripts/factory.sh`. It needs Bash 3.2 or later and Git.

```bash
factory.sh add <id> <brief-file|->
factory.sh start [<id>...] [--max N]
factory.sh status
factory.sh answer <id> <text>
factory.sh logs <id> [lines]
factory.sh merge <id>
factory.sh drop <id>
```

`<id>` is kebab-case. `--max N` sets the maximum number of tasks that run at the same time.

| Variable | Use |
| --- | --- |
| `FACTORY_RUNNER` | The command that runs a worker. It gets the prompt as its last argument. Use an absolute path without spaces. |
| `FACTORY_WORKTREES` | The parent directory of the worktrees. |
| `FACTORY_DRY_RUN=1` | `start` prints the runner command and starts nothing. |

The default runner is `opencode run --agent worker --title "factory/<id>"`. The script adds `--auto` when `opencode run --help` lists it (OpenCode 2). Set `FACTORY_RUNNER` to use a different agent program.

## Models

The worker uses the model of the `worker` agent. See [Agent models](agent-models.md).

## Troubleshooting

| Symptom | Action |
| --- | --- |
| `runner not found` | Install OpenCode, or set `FACTORY_RUNNER`. |
| `this is a factory worktree` | Run the command from the main working tree. |
| A task stays `failed` | Read `/factory logs <id>`. Correct the brief with `answer`, or `drop` the task. |
| `merge` does not change the state | Your working tree has changes in the same files, or a merge is in progress. Commit or complete that work, then merge again. |
