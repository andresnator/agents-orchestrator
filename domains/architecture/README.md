# Architecture Domain

Project-architecture analysis: visual C4-lite docs, state reviews with gap analysis, reverse-engineered PRDs, security/observability audits, and question-driven architecture refactor ideation. Architecture-level only — code-level style and class refactors belong to the `refactor` domain.

One primary agent: `architect`. One subagent: `arch-analyzer` (generic read-only analysis instance, launched N times in parallel with per-lens briefs). A second agent/command pair: `boundary-inspector` (backend service boundary mapping via `service-boundary-analysis`). Five commands sharing the primary: `/arch-map` (C4-lite Mermaid doc set with drift refresh), `/arch-review` (project state + gaps + ranked issue shortlist), `/arch-prd` (reverse-engineered PRD via `prd`/`prd-light`), `/arch-ideate` (ADR + ready-for-sdd bundle), and `/arch-audit` (dependency CVEs, runtime EOL, secrets heuristics, logging posture).

Every mode starts from an inline `architecture-state` scan (toolchain with evidence, architecture style, gaps with fitness-function proposals). Visual docs and PRDs land under the target project's `<docfolder>/architecture/` (existing `docs/`, else `doc/`, else a created `doc/`); reports land under `.ai/architect/reports/`. `/arch-ideate` composes OpenSpec bundles under `.ai/architect/changes/<change>/` using the `sdd-draft-*` templates, adopted by the sdd `orchestraitor` via `docs/plan-handoff.md` ("ejecuta el plan <change>"); group 1 of every ideation bundle turns the decided boundaries into fitness functions (ArchUnit / Spring Modulith / dependency-cruiser / import-linter).

Deliberate precedent: `architect` is the repo's first agent with non-deny bash — an ask-gated allowlist of read-only audit commands (`npm audit`, `mvn dependency:tree`, `pip-audit`, `osv-scanner`, …) under a default `"*": deny`, used only in `/arch-audit`; a denied or missing tool degrades to manifest inspection (`method: manifest-fallback`). `arch-analyzer` stays fully read-only with `bash: deny`.

Full lens coverage assumes the `common` domain is installed (lens skills such as `cohesion-coupling` or `logging-observability` live there, as do the transversal `code-conventions` and `risk-assessment`); missing lens skills are reported as skipped, never as failures. Bundle composition uses the `sdd-draft-*` templates from the `sdd` domain.

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (primary) | `architect` | Analyzes architecture and produces evidence-backed artifacts |
| Agent (subagent) | `arch-analyzer` | Analyzes one architecture lens read-only |
| Agent (subagent) | `boundary-inspector` | Maps backend service boundaries read-only |
| Command | `/arch-audit` | Audits security and observability read-only |
| Command | `/arch-ideate` | Produces an ADR and ready-for-sdd bundle |
| Command | `/arch-map` | Generates or refreshes C4-lite architecture docs |
| Command | `/arch-prd` | Reverse-engineers a PRD from code |
| Command | `/arch-review` | Ranks evidence-backed architecture issues |
| Command | `/boundary-inspector` | Inspects service inputs and outputs |
| Skill | `adr` | Document decisions and architectural trade-offs |
| Skill | `architecture-ideation` | Produce ADR and ready-for-sdd architecture bundle |
| Skill | `architecture-impact-review` | Classify risk as local or architectural |
| Skill | `architecture-map` | Generate evidence-backed C4-lite Mermaid docs |
| Skill | `architecture-state` | Detect architecture gaps and propose fitness functions |
| Skill | `cognitive-doc-design` | Design docs that reduce cognitive load |
| Skill | `dependency-security-audit` | Audit dependency and observability posture |
| Skill | `java-secure-coding` | Review Java security practices |
| Skill | `prd` | Create rigorous high-stakes PRDs |
| Skill | `prd-light` | Create lightweight MVP PRDs |
| Skill | `repo-issues` | Rank evidence-backed repository issues |
| Skill | `service-boundary-analysis` | Map service boundaries with evidence |
| Skill | `tooling-audit` | Detect test safety tooling gaps |
| Skill | `tooling-compatibility-matrix` | Guide test, coverage, and mutation tooling |

```mermaid
graph TD
  map[/arch-map/] --> architect[architect]
  review[/arch-review/] --> architect
  prd[/arch-prd/] --> architect
  ideate[/arch-ideate/] --> architect
  audit[/arch-audit/] --> architect
  architect --> state[inline state scan<br/>architecture-state]
  state --> fanout[arch-analyzer x N<br/>parallel: per-lens briefs]
  fanout --> consolidate[consolidate + adversarial filter]
  consolidate --> docfolder["&lt;docfolder&gt;/architecture/<br/>overview + flows + PRD + ADRs"]
  consolidate --> reports[".ai/architect/reports/<br/>review + audit"]
  consolidate --> bundle[".ai/architect/changes/&lt;change&gt;<br/>Status: ready-for-sdd"]
  bundle --> adopt[orchestraitor plan intake<br/>ejecuta el plan &lt;change&gt;]
```
