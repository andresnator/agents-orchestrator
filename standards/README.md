# Standards

Code and writing standards for agents-orchestrator. Read all files here before you write code or documentation.

## Application summary

agents-orchestrator is a set of OpenCode commands, skills, and plugins. One agent, `orchestraitor`, does all routes: it loads `oc-*` skills or gives work to the `general` subagent. The installer (`installers/opencode.sh`) links the files into the OpenCode configuration folder.

## Files

| File | Use it when you |
| --- | --- |
| [code-conventions.md](code-conventions.md) | Write code, scripts, or tests. |
| [writing-conventions.md](writing-conventions.md) | Write documentation, prompts, skills, comments, or commit messages. |
| [glossary.md](glossary.md) | Use an abbreviation or a technical term. |

## Rules

1. Read all files in this folder.
2. If a project rule is different from a standard, obey the project rule and report the difference.
3. Add each new abbreviation or term to [glossary.md](glossary.md) first.
