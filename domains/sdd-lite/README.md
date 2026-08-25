# SDD Lite Domain (POC)

A bounded implementation flow in one coordinator context. `orchestralite` drafts and executes one `change.md`; only cold verification is delegated.

## Quick path

1. Request an obviously bounded, low-risk change through `sdlc-orchestrator`.
2. Confirm the retained draft when interactive.
3. Review implementation evidence and the archived `change.md`.

## Entry points

| Entry | Use | Result |
|---|---|---|
| Natural-language request | Route a Lite-safe change | `.ai/sdd-lite/changes/<change>/change.md` |
| Existing Lite state | Resume the exact change | Continued implementation or verification |

Lite is intended for roughly five files or fewer, low risk, and no sprawling capability. Scope growth redirects to full SDD before more implementation.

| Lite keeps | Lite omits |
|---|---|
| One durable `change.md` | Canonical spec merge |
| One coordinator context | Implementation fan-out |
| Independent cold verification | Commit-per-wave delivery |
| One bounded fix round | Adversarial judgment loop |

State stays under `.ai/sdd-lite/`, never `.ai/orchestrator/`. Missing changes, unsafe operations, scope expansion, or ambiguous verification block. See [SDD flow verification](../../docs/sdd-test-plan.md).

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (subagent coordinator) | `orchestralite` | Coordinates bounded implementation and archive |
| Agent (subagent) | `lite-verify` | Cold-checks the bounded implementation |
| Skill | `behavior-characterization` | Captures current bounded behavior |
| Skill | `code-conventions` | Applies code and test conventions |
| Skill | `cognitive-doc-design` | Keeps human-facing documentation clear |
| Skill | `java-testing` | Implements focused Java tests |
| Skill | `legacy-code-safety` | Protects bounded legacy changes |
| Skill | `sdd-cold-verification` | Verifies scoped scenarios independently |
| Skill | `sdd-execution-skills` | Selects skills for implementation work |
| Skill | `systematic-debugging` | Finds root causes before fixes |
