# Harness Architecture

This repo is a personal AI agent harness: a place to design, store, validate, and reuse daily AI work tools.

## Mental model

| Layer | Role |
|---|---|
| Agents | Who acts |
| Skills | How capabilities are performed |
| Commands | Fast entry points |
| Recipes | Multi-step playbooks |
| Scenarios | Golden-case validation |
| Templates | Consistent creation patterns |

## Design rule

Keep each piece small and composable. If one file tries to be agent, skill, command, and recipe at once, split it.
