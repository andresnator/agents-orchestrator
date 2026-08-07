# Architecture Domain

Architecture-level mapping, review, PRD recovery, audit, boundary analysis, and ideation. Class-level cleanup belongs to the `refactor` domain.

## Quick path

1. Describe the architecture outcome through `sdlc-orchestrator` or use an alias below.
2. Review evidence-backed outputs under project architecture docs or `.ai/architect/`.
3. For ideation, review the ADR and the single ready `change.md`, then hand that change to SDD.

## Operations

| Alias | Result |
|---|---|
| `/arch-map` | C4-lite architecture documentation |
| `/arch-review` | Ranked architecture issues and fitness functions |
| `/arch-prd` | PRD reverse-engineered from current behavior |
| `/arch-ideate` | ADR plus `.ai/architect/changes/<change>/change.md` |
| `/arch-audit` | Read-only security and observability audit |
| `/boundary-inspector` | Service input, output, API, and consumer map |

`architect` performs the state scan and delegates independent read-only lenses to `arch-analyzer` or boundary work to `boundary-inspector`. Audit commands are deny-by-default; missing or declined tools fall back to manifest inspection.

Ideation keeps its ADR because it records an architecture decision. Its executable SDD handoff is only `change.md`, marked `Status: ready-for-sdd | Source: architect`; every Work group records a routed `Skills:` set and SDD executes it in place without redrafting.

The domain declares the shared `sdd-draft-change` contract directly. It assumes `sdlc` and `common` for routing and analysis; SDD owns later execution. Graph exploration follows the independent [Graphify guide](../../docs/graphify.md).

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (subagent coordinator) | `architect` | Owns architecture operations |
| Agent (subagent) | `arch-analyzer` | Analyzes one read-only architecture lens |
| Agent (subagent) | `boundary-inspector` | Maps service boundaries read-only |
| Command | `/arch-audit` | Audits security and observability |
| Command | `/arch-ideate` | Produces an ADR and executable change |
| Command | `/arch-map` | Generates C4-lite docs |
| Command | `/arch-prd` | Reconstructs a PRD |
| Command | `/arch-review` | Ranks architecture issues |
| Command | `/boundary-inspector` | Inspects service boundaries |
| Skill | `adr` | Records architecture decisions |
| Skill | `architecture-ideation` | Designs target architecture and executable work |
| Skill | `architecture-impact-review` | Classifies architecture impact |
| Skill | `architecture-map` | Creates evidence-backed C4-lite docs |
| Skill | `architecture-state` | Detects architecture state and gaps |
| Skill | `cognitive-doc-design` | Reduces document cognitive load |
| Skill | `code-conventions` | Applies repository code and test conventions |
| Skill | `cohesion-coupling` | Detects cohesion and coupling problems |
| Skill | `dependency-inversion` | Detects concrete boundary dependency risks |
| Skill | `dependency-security-audit` | Audits dependency and observability posture |
| Skill | `design-patterns-pragmatic` | Applies patterns only to real forces |
| Skill | `domain-modeling` | Builds and sharpens domain models |
| Skill | `god-object-detection` | Detects oversized multi-responsibility objects |
| Skill | `input-validation-preconditions` | Detects missing or duplicated preconditions |
| Skill | `java-secure-coding` | Reviews Java security practices |
| Skill | `kiss-yagni` | Prevents speculative architecture complexity |
| Skill | `logging-observability` | Evaluates operational logging and observability |
| Skill | `native-question-ux` | Presents questions through portable native UX |
| Skill | `prd` | Creates rigorous PRDs |
| Skill | `prd-light` | Creates lightweight PRDs |
| Skill | `repo-issues` | Ranks repository issues |
| Skill | `sdd-draft-change` | Drafts the single pre-implementation change document |
| Skill | `sdd-execution-skills` | Selects implementation skills per Work group |
| Skill | `service-boundary-analysis` | Maps service contracts |
| Skill | `tooling-audit` | Detects test-tooling gaps |
| Skill | `tooling-compatibility-matrix` | Selects compatible quality tooling |
