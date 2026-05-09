# Commands

Commands are fast entry points for workflows you want to invoke repeatedly.

## Add a command when

- You use the workflow often.
- The input can be described in one line.
- The command delegates to an agent, subagent, or skill with a clear output.

## Command contract

Each command should document:

- invocation shape
- expected input
- agent or skill used
- output format
- forbidden side effects

## Current commands

None yet.

## Rule

Do not create a command for every skill. Create commands only for daily workflows.
