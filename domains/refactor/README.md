# Refactor Domain

Risk-gated refactor and test-hardening (CDD) planning that produces ready-for-sdd OpenSpec change bundles, plus Java refactor skills and the cross-language `refactor` technique catalog.

This domain owns behavior-preserving work on existing code; features, behavior changes, and technical decisions route to the `plan` domain's Deep Plan operation. `refactor-planner` is a subagent coordinator reached through `sdlc-orchestrator`; both planners hand off to SDD through the same contract in `docs/plan-handoff.md`.

The coordinator scopes and risk-classifies inline (with optional read-only Git history approved through a primary-mediated question), then triages whether a plan is worth composing at all: replacement candidates, frozen zero-churn code, and commodity code exit with a reasoned recommendation instead of a bundle, and a target without a reliable test suite is routed to Hard Plan first. Surviving targets fan out analyzer instances by unit × lens, findings are consolidated, and the coordinator composes OpenSpec bundles under `.ai/refactor-planner/changes/<change>/` using the `sdd-draft-*` templates. A complete bundle returns a ready-for-sdd receipt; SDD executes it in place without redrafting.

`/harden-plan` is the Working-Effectively-with-Legacy-Code path: when the target lacks a safety net, harden first. It always runs the `behavior-safety`, `test-safety-net`, and `tooling` lenses (no risk gating, no structural lenses), inspects whether coverage (e.g. JaCoCo) and mutation (e.g. PIT) tooling is configured — missing tooling becomes explicit enablement tasks — and asks coverage/mutation thresholds at kickoff. Its tasks follow a fixed CDD order: tooling enablement → minimal behavior-preserving seams → characterization and unit tests → coverage/mutation baseline against the thresholds. The full CDD sequence: `/harden-plan` → "ejecuta el plan" (sdd) → archive merges the characterization deltas into canonical specs → `/refactor-plan` on the hardened code with fresh evidence → "ejecuta el plan".

Bundles carry Andres's style contract: the `code-conventions` skill rides the test-safety-net lens, `design.md` records language/tool versions plus convention deviations, and test tasks prescribe the test format (naming, `// Given // When // Then` sections, whole-object asserts, separate characterization classes).

The coordinator profile assumes the `sdlc`, `common`, and `sdd` domains are installed. Full lens coverage uses common skills such as `cohesion-coupling` and `kiss-yagni`; missing lens skills are reported as skipped, never as failures, and a missing `risk-assessment` degrades to a documented inline risk heuristic. Bundle composition uses the `sdd-draft-*` templates from the `sdd` domain.

Legacy note: pre-2026-07 `.ia-refactor/plan/**` artifacts are frozen history. The planner ignores them and `/refactor-execute` no longer exists — execution now happens through sdd adoption.

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (subagent coordinator) | `refactor-planner` | Plans risk-gated refactor or hardening bundles and returns public receipts |
| Agent (subagent) | `refactor-analyzer` | Analyzes one refactor lens read-only |
| Command | `/harden-plan` | Plans characterization, coverage, and mutation safety |
| Command | `/refactor-plan` | Plans behavior-preserving ready-for-sdd refactor bundles |
| Skill | `architecture-impact-review` | Classify risk as local or architectural |
| Skill | `behavior-characterization` | Record current legacy behavior |
| Skill | `characterization-test-scoping` | Scope tests, seams, containment, and rollback |
| Skill | `dependency-seam-detection` | Find seams for legacy testability |
| Skill | `java-api-design` | Design clear Java API boundaries |
| Skill | `java-exception-robustness` | Design robust Java failure handling |
| Skill | `java-immutability-modeling` | Model Java data safely |
| Skill | `java-naming-readability` | Evaluate Java naming and readability |
| Skill | `java-secure-coding` | Review Java security practices |
| Skill | `java-testing` | Generate and retrofit Java tests |
| Skill | `legacy-code-safety` | Make untested code safe to change |
| Skill | `null-safety` | Detect null hazards conservatively |
| Skill | `refactor` | Apply cross-language refactoring techniques |
| Skill | `scope-analysis` | Delimit class, package, or module scope |
| Skill | `tooling-audit` | Detect refactor safety tooling gaps |
| Skill | `tooling-compatibility-matrix` | Guide test, coverage, and mutation tooling |
| Skill | `type-contracts` | Detect weak or implicit Java contracts |

```mermaid
graph TD
  user["Natural language or command alias"] --> sdlc[sdlc-orchestrator]
  sdlc --> planner[refactor-planner coordinator]
  planner --> scope[inline scope + risk + churn<br/>scope-analysis, risk-assessment]
  scope --> triage{triage:<br/>worth a plan?}
  triage -->|replace / frozen / commodity| rec[reasoned recommendation<br/>no bundle]
  triage -->|no safety net| hardenhint[recommend /harden-plan]
  triage -->|yes| fanout[refactor-analyzer x N<br/>parallel: unit x lens]
  fanout --> consolidate[consolidate + self-check]
  consolidate --> bundle[".ai/refactor-planner/changes/&lt;change&gt;<br/>proposal + design + spec deltas + tasks<br/>Status: ready-for-sdd"]
  bundle --> handoff[ready-for-sdd receipt]
  handoff --> sdlc
  sdlc --> sdd[orchestraitor<br/>implement --> verify --> review? --> archive]
  sdd -.->|archive merges characterization,<br/>then refactor with fresh evidence| planner
```
