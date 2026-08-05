# Adopt a Primary SDLC Orchestrator over Domain Coordinators

## Status

Accepted

## Context

The repository organizes reusable OpenCode artifacts by domain but exposes several primary agents. Users must choose an entrypoint before the system can apply domain knowledge, and interactive workflows can surface questions from multiple agent contexts. The POC needs one natural-language entrypoint without merging planning, architecture, refactor, implementation, and review responsibilities into one prompt.

OpenCode 1.18.10 requires `default_agent` to reference a primary agent and supports `subagent_depth: 2`. That depth can represent a primary router, one domain coordinator, and the coordinator's phase agents. Planning artifacts already provide a durable ready-for-sdd boundary under `.ai/<planner>/changes/<change>/`.

## Decision

Adopt `sdlc-orchestrator` as the only repository-owned primary in an opt-in project-local profile. It classifies natural-language intent, delegates only to domain coordinators, validates a shared receipt, and owns every user-facing question. Domain coordinators become subagents and retain their phase-agent topology.

Use `sdlc-coordinator-receipt/v1` as the public coordinator boundary. A coordinator that needs input returns `needs_input`; the primary asks and resumes the same child through OpenCode Task `task_id`. Deep Plan and Hard Plan hand SDD a compact receipt plus the exact ready-for-sdd bundle path, and SDD starts at execution rather than redrafting. Direct SDD retains local planning.

## Options Considered

### Option 1: Monolithic primary

Put every domain workflow in one primary prompt.

**Pros:**
- Fewer delegation hops.

**Cons:**
- Large context and mixed responsibilities.
- Domain workflows become harder to reuse and evolve independently.

### Option 2: Primary delegates directly to phase agents

Let the primary understand and invoke every drafting, analysis, implementation, and verification agent.

**Pros:**
- One less hierarchy level.

**Cons:**
- The primary must own domain sequencing and detailed phase contracts.
- Domain boundaries and coordinator context are lost.

### Option 3: Primary delegates to domain coordinators

Keep routing and questions in one primary while coordinators own their phase agents.

**Pros:**
- Clear boundaries and specialized context.
- Existing domains remain reusable.
- Compact receipts make handoffs inspectable.

**Cons:**
- Requires two nested subagent levels.
- Requires explicit receipts and child-session continuity.

## Consequences

**Positive:**
- Users can start SDLC work in natural language and receive questions in one conversation.
- Planning and execution share durable artifacts without duplicating planning work.
- Each domain retains its own contracts, models, and phase agents.
- The project-local profile is reversible and does not change global OpenCode state.

**Negative:**
- Prompt contracts and static validation cannot guarantee every model routing decision; real-flow evidence remains necessary.
- Temporary command aliases increase the compatibility surface during the POC.
- A two-level hierarchy adds receipt validation and Task ID bookkeeping.

## Follow-up

- Evaluate alias retirement only after demonstrated parity and dependency review.
- Consider generating the domain/dependency catalog from a shared structured source after the POC; do not implement that catalog here.
