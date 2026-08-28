# Use Primary-Only Adaptive Planning and Orchestration

## Status

Accepted

## Context

Public commands exposed overlapping discovery, planning, refactor, hardening, and SDD routes. Users had to choose workflow mechanics before the system knew the change risk.

The repository needs four stable primaries, neutral plans, safe direct execution, and durable SDD only when coordination or risk requires it.

## Decision

Expose Wayfinder and Deep Plan through `deep-planner`, and execute through `orchestraitor`. Remove the public planning and SDD commands without aliases.

Wayfinder writes discovery only. Deep Plan writes one neutral plan. Orchestraitor executes safe work directly and asks before creating SDD state, except when the user explicitly requests SDD.

## Options Considered

### Keep Public Workflow Commands

Keep separate commands for planning, discovery, refactor, hardening, and SDD.

**Pros:**

- Each workflow remains explicit.
- Existing routes stay familiar.

**Cons:**

- Users choose mechanics before risk is known.
- Overlapping outputs require compatibility contracts.

### Use Primary-Only Adaptive Routing

Let primaries infer clear intent and use one closed choice only for ambiguity.

**Pros:**

- Public concepts match discovery, planning, and execution ownership.
- Local changes avoid unnecessary state and workers.
- Complex work retains durable SDD controls.

**Cons:**

- Primary prompts own more routing judgment.
- The clean break removes command compatibility.

## Consequences

**Positive:**

- Every plan is neutral and executable by one primary.
- Direct work stays lightweight.
- SDD state starts only with consent or explicit intent.

**Negative:**

- Removed commands have no aliases or migration path.
- Tests and guides must validate inferred routing instead of command dispatch.
