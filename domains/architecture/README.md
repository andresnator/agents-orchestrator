# Architecture Domain

Evidence-backed architecture maps, reviews, decisions, and service boundaries. Class-level refactors belong to Plan.

## Quick path

1. Install `architecture` or the multi-primary profile.
2. Use an entry point, or ask `orchestraitor` to load `oc-arch`.
3. Review the files under `<docfolder>/architecture/` or `.ai/architect/`. Execute plans through `orchestraitor`.

## Entry points

| Entry | Use | Result |
|---|---|---|
| `/arch map` | Document current architecture | Adaptive C4-lite documentation |
| `/arch review` | Rank architecture risks | Issues and fitness functions |
| `/arch ideate` | Choose a target architecture | ADR and neutral execution plan |
| `/arch boundary` | Inspect one service | Evidence-backed boundary map |

Dependency commands need authorization; without it, they give inventory only.

## Components

Unmarked rows are skills.

| Name | Purpose |
|---|---|
| `/arch` | Runs all architecture operations |
| `oc-arch` | Coordinates all architecture operations |
| `oc-adr` | Records architecture decisions |
| `oc-conventions` (handoff-only) | Names SDD implementation conventions |
| `oc-java-test` (handoff-only) | Names Java testing guidance |
| `oc-dep-audit` | Audits current dependency evidence |
| `oc-patterns` | Applies patterns to evidenced forces |
| `oc-refactor-lens` | Supplies the `kiss` lens |
| `oc-plan-format` | Drafts one neutral execution plan |
| `oc-routing` | Selects implementation skills |
| `oc-boundary` | Maps service contracts |
