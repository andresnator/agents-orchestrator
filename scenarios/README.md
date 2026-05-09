# Scenarios

Scenarios are golden-case validations for agents, subagents, skills, and commands.

This repo mostly contains Markdown instructions, so validation is scenario-based instead of unit-test based.

## Scenario contract

Each scenario should define:

- input
- expected verdict or behavior
- must include
- must not include
- notes for manual review

## Current scenario suites

| Suite | Purpose |
|---|---|
| [`buildable-issue`](buildable-issue/) | Validate buildable issue creation, enrichment, and legacy trigger compatibility |
| [`doc-command`](doc-command/) | Validate `/doc` as a thin documentation shortcut |
| [`prompt-evaluator`](prompt-evaluator/) | Validate prompt-only review behavior |
