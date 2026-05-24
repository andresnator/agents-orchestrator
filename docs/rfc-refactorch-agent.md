# RFC: refactorch Agent

| Field | Value |
|-------|-------|
| **Feature Name** | `refactorch-agent` |
| **Type** | Enhancement |
| **Status** | Draft |
| **Start Date** | 2026-05-22 |
| **Author(s)** | Andrés |
| **Related Components** | `agents/primary/`, `agents/subagents/`, Engram project memory |
| **Related Issues** | N/A |

---

## Summary

`refactorch` is a primary agent for safe refactoring workflows. The first implementation slice adds the primary agent and `scout` so refactor workflows can establish reusable project context and a target brief before any deeper planning. `planner` and `gatekeeper` remain follow-up subagents; execution and post-implementation auditing are future phases. The goal is to avoid repeated project discovery while keeping each agent responsibility narrow and reviewable.

## Motivation

Refactoring with AI is risky when the agent starts changing code before understanding the project language, test commands, tooling, and safety net. Re-discovering that information in every step also wastes context and creates repeated responsibilities across agents. `refactorch` solves this by separating global project discovery from class-specific refactor planning and by adding explicit safety gates before and after code changes.

If this is not built, refactor workflows will keep depending on ad hoc prompting, repeated exploration, and overloaded reviewer roles that mix plan validation with post-change auditing.

## Detailed Design

### Agent Roles

`refactorch` is the primary orchestrator. It should stay thin: it does not own heavy code context, does not perform broad repository exploration itself, and does not directly refactor code. It delegates bounded work to subagents and synthesizes their results for the user.

The proposed subagents are:

| Agent | Phase | Responsibility | Output |
|-------|-------|----------------|--------|
| `scout` | Implemented setup slice | Build or refresh the reusable Project Profile. | Project Profile saved to Engram. |
| `planner` | Follow-up v1 | Analyze the requested refactor target and produce a safe refactor plan. | Refactor plan with target, smells, tests needed, steps, and risks. |
| `gatekeeper` | Follow-up v1 | Review the plan before code changes. | Proceed / revise / block recommendation. |
| `executor` | Future | Apply approved refactor steps. | Code changes plus verification notes. |
| `auditor` | Future | Review the final diff after execution. | Post-change audit with behavior, tests, and remaining risks. |

The current implemented boundary is setup only: `refactorch` plus `scout`. The broader v1 boundary remains planning and gating only once `planner` and `gatekeeper` are added. `executor` and `auditor` describe the intended full workflow, but they should not be implemented until the planning workflow is stable.

### Agent Contract Requirements

When this RFC becomes implementation work, each agent file must state:

- responsibility
- permissions and forbidden actions
- related skills
- input shape
- output contract

This follows the repository convention for primary and subagent definitions.

### Project Profile

The Project Profile is reusable technical context for the current repository. It should be produced once by `scout`, stored in Engram, and reused by later phases instead of rediscovering the same information.

The reusable topic key is owned by the named skill `refactorch-phases`; the Project Profile document shape and refresh workflow are owned by the `scout` subagent contract at `agents/subagents/scout.md` so agent files and this RFC do not drift from executable contracts.

### Shared Contract Skill

`refactorch` should copy the useful part of the Gentle SDD Engram flow: agents create durable Markdown artifacts in Engram, and the orchestrator passes artifact references between phases instead of copying large documents through the primary context.

The shared communication rules live in a skill artifact; the Scout-specific profile workflow lives directly in the `scout` subagent contract:

```txt
skills/refactorch-phases/SKILL.md
agents/subagents/scout.md
```

The shared phase skill owns:

- topic keys
- common input shape
- shared output envelope
- Engram read/write rules
- `target-brief` ownership, timing, and minimal document shape
- artifact reference format

The `scout` subagent owns:

- Project Profile document shape
- Project Profile create/refresh workflow
- refresh triggers
- output details

Agent files should not duplicate those contracts. Agents should use the named skill `refactorch-phases` for shared phase rules and the `scout` subagent contract for Project Profile workflow.

The artifact remains the real contract. The routing envelope only tells the caller where the document lives, what happened, and what should happen next.

### Example Workflow

When the user says:

```txt
Quiero refactorizar la clase A
```

the target orchestration should eventually follow this path. The currently implemented slice stops after the `target-brief` handoff boundary because `planner` and `gatekeeper` are follow-up subagents.

```txt
User request
  -> refactorch identifies target class A
  -> refactorch checks for Project Profile in Engram
      -> if missing: scout creates and saves it
      -> if present: refactorch loads it
  -> refactorch writes a target-brief artifact and passes its reference
  -> planner analyzes class A, its tests, and important callers
  -> planner proposes a small-step refactor plan
  -> gatekeeper reviews the plan before code changes
      -> if unsafe: stop and ask for revision or tests first
      -> if safe in v1: stop with an approved plan
      -> if safe in a future version: executor applies the approved steps
  -> future: executor runs the relevant verification commands
  -> future: auditor reviews the final diff and verification evidence
  -> refactorch summarizes the current result and remaining next steps
```

### Responsibility Boundaries

The design intentionally avoids combining pre-change and post-change review in one `reviewer` agent.

- `gatekeeper` exists before implementation and asks: “Is this plan safe to execute?”
- `auditor` exists after implementation and asks: “Did the implementation preserve behavior and satisfy the goal?”

This keeps each subagent aligned with a single reason to change.

### Initial Scope

The first version should support one focused request:

```txt
Quiero refactorizar la clase <Target>
```

The current setup slice should produce reusable Project Profile context and a target brief before any code edits. A follow-up v1 slice should add the plan and safety recommendation. Actual code execution and post-change auditing can be added after the planning and gating workflow is stable.

## Drawbacks

This design adds workflow structure before code changes, so it may feel slower than a direct “just refactor this” prompt. It also depends on the quality of the Project Profile: stale or incomplete profile data can mislead later planning if `scout` does not know when to refresh it.

Splitting `gatekeeper` and `auditor` adds one more subagent, but the separation prevents a single overloaded reviewer from mixing plan risk with diff verification.

## Alternatives

One alternative is a single `reviewer` agent that validates both the plan and the final diff. This was rejected because it has two responsibilities and two separate reasons to change.

Another alternative is to keep separate `project-profiler` and `test-capability-scanner` agents. This was rejected because both repeatedly inspect the same project-level context. Consolidating them into `scout` keeps discovery in one place.

A third alternative is to skip a Project Profile and let each subagent inspect the repository independently. This was rejected because it repeats expensive discovery and increases the chance of inconsistent assumptions between phases.

## Unresolved Questions

- Should `scout` use age-based freshness thresholds in addition to the structural refresh triggers defined in the `scout` subagent contract?
- Should `gatekeeper` be allowed to block execution automatically, or should it only recommend blocking to the user?
