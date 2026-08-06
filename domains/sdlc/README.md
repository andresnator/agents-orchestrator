# SDLC Domain

`sdlc-orchestrator` is the project profile's single entrypoint and user-question owner. It routes intent; domain coordinators own execution and may delegate one level further.

## Quick path

1. Install the [SDLC POC profile](../../docs/sdlc-orchestrator-poc.md).
2. Describe the outcome in natural language.
3. Answer any question in the primary session; the primary resumes the same coordinator child.

## Routes

| Intent | Coordinator | Operation |
|---|---|---|
| Executable, decision, discovery, or roadmap planning | `deep-planner` | `deep-plan` with `auto` or `discovery` intent |
| Behavior-preserving refactor or test safety net | `deep-planner` | `refactor` with `auto` or `hardening` intent |
| Full implementation, resume, or ready change | `orchestraitor` | `direct-sdd`, `resume`, or `execute-handoff` |
| Bounded low-risk implementation | `orchestralite` | `sdd-lite` |
| Architecture work | `architect` | requested architecture operation |
| Judgment or Socratic defense | `review-coordinator` | `judgment` or `defend` |

The primary shows choices only when intent is ambiguous. The profile sets `subagent_depth: 2`; its Task allowlist stops at the coordinators.

## Compact A2A

Coordinator and worker returns use terse Caveman-style fragments. Omit absent fields and keep a clean return to five lines or fewer:

```text
OK plan/deep-plan
artifact=.ai/deep-planner/changes/add-timeout/change.md
next=sdd handoff=.ai/deep-planner/changes/add-timeout/change.md
```

```text
ASK sdd/direct-sdd Which test mode should be used?
BLOCK sdd/resume ambiguous active changes; next=choose path
FAIL sdd/verify mvn test failed
```

Findings use one line per finding plus one totals line. Paths, symbols, ids, commands, errors, and numbers stay exact. Security, irreversible actions, user questions, and ambiguous compressed text use normal language. Raw A2A is never the final user response.

This local contract adapts [Caveman Cavecrew's compressed subagent-return pattern](https://github.com/JuliusBrussee/caveman/tree/main/skills/cavecrew); it adds no runtime dependency.

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (primary) | `sdlc-orchestrator` | Routes SDLC intent and owns user-facing questions |
| Agent (subagent) | `review-coordinator` | Coordinates Judgment and Defend |
| Skill | `judgment-day` | Runs dual blind adversarial reviews |
| Skill | `programming-practices-core` | Evaluates language-neutral code quality |

The domain defines no commands. Compatibility aliases stay with their owner domains.
