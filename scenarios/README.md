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
| [`english-tutor-agent`](english-tutor-agent/) | Validate explicit English coaching, five-field corrections, `/english`, privacy boundaries, and passive limitation disclosure |
| [`java-refactor-anchor-first`](java-refactor-anchor-first/) | Validate dumb-primary routing, Java refactor gates, optional TCR mode, and evidence curation |
| [`prompt-evaluator`](prompt-evaluator/) | Validate prompt-only review behavior |
| [`programming-practices-skills`](programming-practices-skills/) | Validate autonomous programming-practice skills for Clean Code, Java design, secure coding, and pragmatic patterns |
| [`service-boundary-analysis`](service-boundary-analysis/) | Validate service boundary input/output classification, evidence, confidence, and uncertainty handling |
