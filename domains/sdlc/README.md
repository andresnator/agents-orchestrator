# SDLC Domain

`sdlc-orchestrator` is the profile's single natural-language entry point and user-question owner. Domain coordinators own specialized execution.

## Quick path

1. Install the [SDLC POC profile](../../docs/sdlc-orchestrator-poc.md).
2. Describe the desired outcome in natural language.
3. Answer questions in the primary session; it resumes the same coordinator child.

## Entry points

| Intent | Coordinator | Operation |
|---|---|---|
| Planning, decisions, discovery, or roadmaps | `deep-planner` | `deep-plan` |
| Refactor or test hardening | `deep-planner` | `refactor` |
| Full implementation or resume | `orchestraitor` | Full SDD operation |
| Bounded low-risk implementation | `orchestralite` | `sdd-lite` |
| Architecture work | `architect` | Requested architecture operation |
| Judgment or Socratic defense | `review-coordinator` | `judgment` or `defend` |

The profile sets `subagent_depth: 2`; the primary delegates only to coordinators. Returns use compact A2A lines such as `OK plan/deep-plan`, `ASK sdd/direct-sdd ...`, `BLOCK ...`, or `FAIL ...`. The primary paraphrases them for users and uses normal language for questions, security, irreversible actions, or ambiguity.

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (primary) | `sdlc-orchestrator` | Routes intent and owns questions |
| Agent (subagent) | `review-coordinator` | Coordinates Judgment and Defend |
| Skill | `judgment-day` | Runs dual blind adversarial reviews |
| Skill | `programming-practices-core` | Evaluates language-neutral code quality |
