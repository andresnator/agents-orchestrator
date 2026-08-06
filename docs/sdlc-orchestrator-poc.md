# Run the SDLC Orchestrator POC

The opt-in project profile makes `sdlc-orchestrator` the single natural-language entrypoint. It owns routing and user questions; six domain coordinators own specialized work and may delegate only their phase agents.

## Quick path

Use an absolute target outside this source repository and its worktrees:

```bash
scripts/sdlc-orchestrator-poc.sh install --project-root /absolute/path/to/project
scripts/sdlc-orchestrator-poc.sh status --project-root /absolute/path/to/project
scripts/sdlc-orchestrator-poc.sh uninstall --project-root /absolute/path/to/project
```

The profile installs `sdlc,plan,sdd,architecture,refactor,sdd-lite,common` into the project's `.opencode/` and applies:

```jsonc
{
  "default_agent": "sdlc-orchestrator",
  "subagent_depth": 2
}
```

The generic installer remains the supported route for other domain combinations.

## Routes

| Intent | Coordinator | Durable result |
|---|---|---|
| Executable or decision planning | `deep-planner` | `change.md`, decision plan, or Wayfinder map |
| Test hardening or behavior-preserving refactor | `refactor-planner` | Ready `change.md` or reasoned no-plan result |
| Full SDD, resume, or ready handoff | `orchestraitor` | Implementation, canonical specs, archived change |
| Bounded low-risk implementation | `orchestralite` | Implementation and archived `change.md` |
| Architecture operation | `architect` | Architecture docs, reports, ADR, or ready `change.md` |
| Judgment or Defend | `review-coordinator` | Findings, fixes, verdict, or defense outcome |

Commands such as `/deep-plan`, `/harden-plan`, `/arch-ideate`, `/judgment`, and `/defend` are compatibility aliases through the same primary. The primary shows options only for ambiguous intent.

## Topology decision

The profile uses `primary -> domain coordinator -> phase agent`. This keeps question ownership and routing small while domain coordinators retain their sequencing, permissions, and model assignment. `subagent_depth: 2` is therefore load-bearing. A monolithic primary would mix every workflow; direct primary-to-worker routing would duplicate domain sequencing.

Coordinators return compact A2A fragments rather than a shared wide schema:

```text
OK architecture/ideate
artifact=.ai/architect/changes/modularize-orders/change.md
next=sdd handoff=.ai/architect/changes/modularize-orders/change.md
```

Absent fields are omitted. Clean returns are at most five lines; findings use one line per finding. The primary paraphrases for humans and switches to normal language for questions, security, irreversible actions, or ambiguity.

## One-document SDD handoff

Deep Plan, Refactor/Hardening, and Architecture Ideate write one file:

```text
.ai/<producer>/changes/<change>/change.md
```

Its marker is `Status: ready-for-sdd | Source: <producer>`. The rest records outcome, scope, behavior deltas, approach, work groups, verification, and non-empty risks. SDD receives the exact path, adopts it in place, adds `state.md`, and starts execution without copying or redrafting. Old four-file bundles are not discovered automatically.

Direct SDD writes the same shape under `.ai/orchestrator/changes/`. SDD Lite keeps its state under `.ai/sdd-lite/` and does not merge canonical specs.

## Ownership and rollback

`.agents-orchestrator-manifest` owns installed components. `.sdlc-orchestrator-poc-manifest` owns the selected profile and the prior values of `default_agent` and `subagent_depth`.

Install preflights downloads and refuses broad, foreign, invalid, escaping, home, root, source-repository, or worktree targets. Status and uninstall fail closed on tampering. A clean uninstall removes only manifest-owned components, restores prior JSONC scalar values, preserves comments and foreign keys, and removes the profile manifest.

## Verification

Free checks:

```bash
scripts/test-sdlc-orchestrator-contracts.sh
scripts/test-plan-sdd-contracts.sh
scripts/test-sdlc-orchestrator-poc.sh
scripts/test-external-plugin-install.sh contracts
scripts/validate-harness.sh
```

The paid POC runner performs exactly one Plan-to-SDD workflow and one bounded Lite workflow, with no automatic retry:

```bash
SDLC_POC_E2E_CONFIRM=run-exactly-two-paid-workflows \
  OPENCODE_BIN=/absolute/path/to/opencode \
  scripts/test-sdlc-orchestrator-e2e.sh
```

The simplified POC passed its authorized real-model run on 2026-08-06 with OpenCode 1.18.10: exactly two workflows, three OpenCode calls, and zero retries. Plan produced one ready `change.md`; the same primary session routed it through SDD implementation, cold verification, canonical-spec merge, and producer-root archive. Lite routed through `orchestralite` and one `lite-verify`, kept full-SDD state absent, archived its single `change.md`, and finished with Maven green. Ignored evidence is under `.ai/evidence/sdlc-orchestrator-poc/20260806T074118Z/`.

## Limitations

- Route selection is model behavior constrained by contracts, not a static parser.
- Learning remains independent: `/learn` uses `mentor` and is not routed through this SDLC profile.
- Same-child continuation depends on OpenCode Task IDs; persisted `change.md` and `state.md` support new-session recovery.
- Ambiguous active changes require the user to select an exact path.
- User edits to manifest-owned config stop status or uninstall until resolved.
- The profile is reversible POC scope, not a migration of unrelated domains or global OpenCode state.
