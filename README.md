# Personal AI Agent Harness

My personal workbench for designing, organizing, validating, and reusing AI agents, subagents, skills, commands, and workflows for day-to-day software work.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Discover

| Area | What lives there |
|---|---|
| [`agents/`](agents/) | Primary agents and focused subagents |
| [`skills/`](skills/) | Reusable instruction contracts and references |
| [`commands/`](commands/) | Fast entry points for repeated workflows |
| [`recipes/`](recipes/) | Playbooks that combine tools and judgment |
| [`scripts/`](scripts/) | Local harness management utilities |
| [`templates/`](templates/) | Starting points for new harness pieces |
| [`docs/`](docs/) | Architecture and deeper design notes |

## Recommended entry points

| Tool | Type | Purpose |
|---|---|---|
| [`/doc`](commands/doc.md) | Command | Starts a thin documentation request and routes to the smallest matching documentation skill |
| [`buildable-issue`](skills/buildable-issue/) | Skill | Creates agent-ready GitHub issues that are ready to build |
| [`java-refactor-anchor-first`](agents/primary/java-refactor-anchor-first.md) | Primary agent | Coordinates safe Java refactors through Engram-backed gates without loading the full codebase into the orchestrator |
| [`/promt-checker`](commands/promt-checker.md) | Command | Evaluate and refine prompt text without executing it |
| [`prompt-evaluator`](skills/prompt-evaluator/) | Skill | Defines the prompt evaluation rubric and output contract |

This is a curated list, not a full inventory. Add only broadly useful entry points.

## How this harness is organized

The core separation is simple:

- **Agents** decide who acts and with what boundaries.
- **Skills** define how a capability is performed.
- **Thin wrappers** such as [`scout`](agents/subagents/scout.md) preserve platform boundaries while named skills like [`refactorch-phases`](skills/refactorch-phases/) and [`scout`](skills/scout/) own workflow details.
- **Commands** provide quick invocation paths.
- **Recipes** document workflows across multiple tools.
- **Static documentation review** validates prompt-only behavior without needing a runtime test framework.
- **Templates** keep future additions consistent.

## Add something new

1. Pick the right layer: agent, skill, command, recipe, or template.
2. Start from [`templates/`](templates/).
3. Add or update the section README.
4. Check whether documentation should be updated; keep it concise and useful for future agents.
5. Add concise review notes or checklist items when behavior matters.

## Philosophy

This is not a prompt dump. Each tool should have a clear job, explicit boundaries, and a way to validate that it still behaves correctly.
