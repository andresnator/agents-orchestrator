# Harness Consolidation Migration - 2026-07-05

Superseded operationally by `2026-07-06-domain-restructure.md`. The paths below document the historical migration state from July 5 and are not current install instructions.

## Migrated

| Source | Destination | Notes |
|---|---|---|
| `plan-refactor/.opencode/skills/*` | `catalog/skills/refactor/*`, `catalog/skills/quality/*` | 29 skills migrated from the canonical refactor harness. |
| `plan-refactor/.opencode/agents/*` | `catalog/agents/*` + `catalog/prompts/refactor/*` | 20 agents split into bodyless stubs and prompt bodies. |
| `plan-refactor/.opencode/commands/*` | `catalog/commands/*` + `catalog/prompts/refactor/*` | `/refactor-plan` and `/legacy-safety-plan` migrated. |
| `arnes-develop/.opencode/prompts/*` and `opencode.json` | `catalog/agents/*` + `catalog/prompts/sdd/*` | 14 SDD agents migrated with portable stubs and OpenCode overrides. |
| `arnes-develop/.opencode/command/*` | `catalog/commands/*` + `catalog/prompts/sdd/*` | 6 SDD commands migrated with prefixed command names. |
| `arnes-develop/.opencode/skills/{context-handoff,elicit,sdd-workflow}` | `catalog/skills/sdd/*` | 3 SDD skills migrated. |

## Renamed

| Source name | Catalog name |
|---|---|
| `orchestrator` | `sdd-orchestrator` |
| `build` | `sdd-build` |
| `explore` | `sdd-explore` |
| `review-quality` | `sdd-review-quality` |
| `review-risk` | `sdd-review-risk` |
| `/quick` | `/sdd-quick` |
| `/review` | `/sdd-review` |
| `/ship` | `/sdd-ship` |

## Fused

| Source | Destination | Result |
|---|---|---|
| `arnes-develop/.opencode/skills/judgment-day` | `catalog/skills/engineering/judgment-day/SKILL.md` | Existing skill bumped to `1.2.0` with the pre-registered `jd-judge-a`, `jd-judge-b`, `jd-fix` delegation note and orchestrator-only rule. |
| `arnes-develop/docs/state-contract.md` | `catalog/skills/sdd/sdd-workflow/references/state-contract.md` | State lifecycle kept as a workflow reference. |

## Discarded

| Source | Reason |
|---|---|
| `evaluate-coverage` and `legacy-java-test` refactor-safety-plan harnesses | Duplicates of the older folder-OpenSpec contract, superseded by `plan-refactor`. |
| `refactor-safety-plan-contract`, `test-safety-planning`, `openspec-composition`, `safety-gate-review`, and shared copied skills from the duplicate harnesses | Superseded by the canonical `plan-refactor` generation. |
| `arnes-develop/.opencode/skills/judgment-day` as a standalone skill | Fused into the existing catalog skill. |
| Legacy Maven sample app, `.opencode-test-fixtures/`, `node_modules`, lockfiles, `.atl/`, `.ia-refactor/`, local Claude settings | Application/runtime/generated/local state, not catalog artifacts. |

## No Automatizado

- Current operational notes live in `2026-07-06-domain-restructure.md` and `../opencode.md`.
- `domains/refactor/plugins/write-guard.ts` is installed by the current OpenCode installer when the refactor domain is selected.
- Top-level `skills/` contains skill bodies; `domains/*/skills/*` symlinks declare domain usage.

## Promotion Checklist

- Run `installers/opencode.sh install --dry-run`.
- Run `installers/opencode.sh install --target <scratch>/oc-test` and inspect manifest counts, symlinks, and representative links.
- Exercise `/refactor-plan` and `/sdd-new` in a real OpenCode session.
- Promote components from `in-progress` to `testing` with patch version bumps only after the live validation passes.
