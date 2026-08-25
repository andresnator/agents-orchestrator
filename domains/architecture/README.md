# Architecture Domain

Evidence-backed architecture maps, reviews, target decisions, and service-boundary reports. Class-level cleanup belongs to the Plan domain's protected `refactor` route (`/refactor-plan`); product requirements belong to the Docs domain (`/prd`).

## Quick path

1. Describe the architecture outcome through `sdlc-orchestrator` or use an alias below.
2. Review maps under `<docfolder>/architecture/` and reports under `.ai/architect/`.
3. For ideation, review the ADR and ready `change.md`, then hand that exact file to SDD.

## Operations

| Alias | Result |
|---|---|
| `/arch-map` | Adaptive C4-lite docs: one file by default, split only when needed |
| `/arch-review` | Ranked issues and fitness functions; optional dependency-risk focus |
| `/arch-ideate` | ADR plus `.ai/architect/changes/<change>/change.md` |
| `/boundary-inspector` | Static service input/output map |

`architect` executes all four operations inline. State discovery runs for maps, reviews, and ideation; a boundary inspection uses only its exact target. Dependency commands require authorization and degrade to inventory-only results, never guessed vulnerability or EOL claims. The global installer attempts to install selected Homebrew audit tools (`osv-scanner` and `govulncheck`) by default; project installs require `--install-brew-tools`. Audit execution itself never installs tools.

Ideation writes one `Status: ready-for-sdd | Source: architect` `change.md`. Every Work group records routed implementation skill names; SDD executes the file in place without redrafting. `code-conventions` is handoff-only: Architecture may emit its name but never loads its body.

Commands require the `sdlc` domain for routing. SDD owns later execution. Graph exploration follows the independent [Graphify guide](../../docs/graphify.md).

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (subagent coordinator) | `architect` | Owns every architecture operation |
| Command | `/arch-ideate` | Produces an ADR and executable change |
| Command | `/arch-map` | Generates or refreshes C4-lite docs |
| Command | `/arch-review` | Ranks architecture and dependency risks |
| Command | `/boundary-inspector` | Maps one service boundary |
| Skill | `adr` | Records architecture decisions |
| Skill | `architecture-ideation` | Designs target architecture and executable work |
| Skill | `architecture-map` | Creates evidence-backed C4-lite docs |
| Skill | `architecture-state` | Records verified current architecture |
| Skill (handoff-only) | `code-conventions` | Names implementation conventions for SDD |
| Skill | `dependency-security-audit` | Audits current dependency evidence |
| Skill | `design-patterns-pragmatic` | Applies patterns only to evidenced forces |
| Skill | `kiss-yagni` | Rejects speculative architecture complexity |
| Skill | `repo-issues` | Ranks gaps and selects fitness functions |
| Skill | `sdd-draft-change` | Drafts the pre-implementation change |
| Skill | `sdd-execution-skills` | Selects implementation skills per Work group |
| Skill | `service-boundary-analysis` | Maps service contracts |
