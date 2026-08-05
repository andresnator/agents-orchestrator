# SDLC Domain

Use `sdlc-orchestrator` as the single project-local entrypoint for software-delivery work. It routes natural language to existing domain coordinators, keeps their specialized phase agents behind one boundary, and is the only profile agent that asks the user questions.

## Quick path

1. Install the SDLC profile into a project.
2. Describe the outcome in natural language; a clear request routes immediately.
3. Answer questions in the primary session. The primary resumes the same coordinator child rather than restarting it.

The primary shows a menu only for ambiguous requests or when the user asks for options. Refactor and SDD Lite are presented as `[Beta] Refactor` and `[Beta] SDD Lite`.

## Routes

| Route | Coordinator | Notes |
| --- | --- | --- |
| Plan — Deep Plan | `deep-planner` | Produces a durable ready-for-sdd bundle for executable goals. |
| Plan — Hard Plan | `refactor-planner` | Uses `operation: hardening`. |
| [Beta] Refactor | `refactor-planner` | Behavior-preserving work only. |
| SDD | `orchestraitor` | Direct entry plans locally; a ready handoff starts at execution. |
| [Beta] SDD Lite | `orchestralite` | Bounded, low-risk changes with one cold verify. |
| Architecture | `architect` | Map, review, PRD, ideate, audit, or boundary work. |
| Review | `review-coordinator` | Judgment and Socratic Defend. |

The profile sets OpenCode's `subagent_depth` to `2`, allowing the topology `primary -> domain coordinator -> phase agent`. The primary's Task allowlist stops at coordinators.

## Question and receipt loop

Coordinators have `question: deny`. If one needs a decision, it returns `status: needs_input` in an `sdlc-coordinator-receipt/v1`; the primary asks the question and resumes that coordinator through the Task result's `task_id`. Completed coordinators return the same schema with compact artifacts, decisions, scope, acceptance criteria, risks, next-route advice, and optional ready-for-sdd handoff.

The schema and receipt conventions are documented in [`docs/delegation-receipts.md`](../../docs/delegation-receipts.md). Plan-to-SDD artifact semantics are in [`docs/plan-handoff.md`](../../docs/plan-handoff.md).

## Components

| Type | Name | Purpose |
| --- | --- | --- |
| Agent (primary) | `sdlc-orchestrator` | Routes natural-language SDLC intent and owns every user question |
| Agent (subagent) | `review-coordinator` | Coordinates Judgment and Defend through primary-mediated questions |

The domain contains no commands. Existing commands remain compatibility aliases in their owner domains, while the primary supports the same workflows without commands.
