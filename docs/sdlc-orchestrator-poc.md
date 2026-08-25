# Run the SDLC Orchestrator POC

The opt-in project profile makes `sdlc-orchestrator` the single natural-language entrypoint. It owns routing and user questions; five domain coordinators own specialized work and delegate only when their operation needs a phase agent.

## Quick path

Use an absolute target outside this source repository and its worktrees:

```bash
scripts/sdlc-orchestrator-poc.sh install --project-root /absolute/path/to/project
scripts/sdlc-orchestrator-poc.sh status --project-root /absolute/path/to/project
scripts/sdlc-orchestrator-poc.sh uninstall --project-root /absolute/path/to/project
```

Project installs do not change Homebrew by default. Add `--install-brew-tools` to install missing formulas required by the selected profile, or `--no-install-brew-tools` to make the skip explicit. Homebrew tools are shared machine state and are never removed by profile uninstall.

The profile installs `sdlc,plan,sdd,architecture,sdd-lite,common` into the project's `.opencode/` and applies:

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
| Executable, decision, discovery, or roadmap planning | `deep-planner` | `change.md`, durable plan, or roadmap slice |
| Test hardening or behavior-preserving refactor | `deep-planner` | Ready `change.md` or reasoned no-plan result |
| Full SDD, resume, or ready handoff | `orchestraitor` | Implementation, canonical specs, archived change |
| Bounded low-risk implementation | `orchestralite` | Implementation and archived `change.md` |
| Architecture operation | `architect` | Architecture docs, reports, ADR, or ready `change.md` |
| Judgment or Defend | `review-coordinator` | Findings, fixes, verdict, or defense outcome |

Commands such as `/deep-plan`, `/wayfinder`, `/harden-plan`, `/arch-ideate`, `/judgment`, and `/defend` route through the same primary. Plan aliases select `auto`, `discovery`, or `hardening` intent; the primary shows options only for ambiguous intent.

## Topology decision

The profile uses `primary -> domain coordinator`, with a phase agent only when independent work or verification adds value. This keeps question ownership and routing small while coordinators retain sequencing and permissions. `subagent_depth: 2` remains load-bearing for those delegated flows. A monolithic primary would mix every workflow; direct primary-to-worker routing would duplicate domain sequencing.

Coordinators return compact A2A fragments rather than a shared wide schema:

```text
OK architecture/ideate
artifact=.ai/architect/changes/modularize-orders/change.md
next=sdd handoff=.ai/architect/changes/modularize-orders/change.md
```

Absent fields are omitted. Clean returns are at most five lines; findings use one line per finding. The primary paraphrases for humans and switches to normal language for questions, security, irreversible actions, or ambiguity.

## One-document SDD handoff

Deep Plan, protected Refactor/Hardening, and Architecture Ideate write one file:

```text
.ai/<producer>/changes/<change>/change.md
```

Its marker is `Status: ready-for-sdd | Source: <producer>`. It records outcome, scope, behavior deltas, approach, work groups with up to three routed skill names, verification, and non-empty risks. SDD adopts the exact path, resolves names through the generated registry or runtime catalog, adds `state.md`, and executes without copying or redrafting.

Direct SDD writes the same shape under `.ai/orchestrator/changes/`. SDD Lite keeps its state under `.ai/sdd-lite/` and does not merge canonical specs.

## Ownership and rollback

`.agents-orchestrator-manifest` owns installed components. `.sdlc-orchestrator-poc-manifest` owns the selected profile, prior scalar values, and whether the local config and target existed.

Install preflights downloads and refuses broad, foreign, invalid, escaping, home, root, source-repository, or worktree targets. Status and uninstall fail closed on tampering. A clean uninstall restores missing config to absence, preserves comments and foreign keys, and prunes only an empty target created by the profile. Optional Homebrew installation runs after the OpenCode sync; missing Homebrew or formula failures warn without rolling back the profile.

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
