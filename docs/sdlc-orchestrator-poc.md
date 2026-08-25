# Run the SDLC Orchestrator POC

This opt-in project profile makes `sdlc-orchestrator` the natural-language entry point and user-question owner. Domain coordinators own specialized work.

## Quick path

Use an absolute target outside this repository and its worktrees:

```bash
scripts/sdlc-orchestrator-poc.sh install --project-root /absolute/path/to/project
scripts/sdlc-orchestrator-poc.sh status --project-root /absolute/path/to/project
scripts/sdlc-orchestrator-poc.sh uninstall --project-root /absolute/path/to/project
```

Project installs skip Homebrew by default. Add `--install-brew-tools` to install missing profile formulas or `--no-install-brew-tools` to make the skip explicit. Uninstall never removes Homebrew tools.

## Profile and routes

The profile installs `sdlc,plan,sdd,architecture,sdd-lite,common` into `.opencode/` and applies:

```jsonc
{
  "default_agent": "sdlc-orchestrator",
  "subagent_depth": 2
}
```

| Intent | Coordinator | Durable result |
|---|---|---|
| Planning, decisions, discovery, or roadmaps | `deep-planner` | Change, plan, or roadmap slice |
| Test hardening or protected refactor | `deep-planner` | Ready change or reasoned stop |
| Full implementation, resume, or handoff | `orchestraitor` | Implementation, specs, and archive |
| Bounded low-risk implementation | `orchestralite` | Implementation and archived change |
| Architecture work | `architect` | Docs, reports, ADR, or change |
| Judgment or Defend | `review-coordinator` | Findings, fixes, or defense outcome |

Commands such as `/deep-plan`, `/wayfinder`, `/harden-plan`, `/arch-ideate`, `/judgment`, and `/defend` use the same primary. The primary presents choices only when intent is ambiguous.

The topology is `primary -> domain coordinator -> optional phase agent`. `subagent_depth: 2` is required. Coordinators return compact `OK`, `ASK`, `BLOCK`, or `FAIL` lines; the primary paraphrases them for users and keeps questions in normal language.

## One-document handoff

Plan, protected Refactor or Hardening, and Architecture Ideate write:

```text
.ai/<producer>/changes/<change>/change.md
```

The first line is `Status: ready-for-sdd | Source: <producer>`. The file contains outcome, scope, behavior deltas, approach, work groups with up to three routed skill names, verification, and risks.

SDD adopts the exact path, adds `state.md`, and executes without copying or redrafting. Direct SDD uses `.ai/orchestrator/changes/`; Lite uses `.ai/sdd-lite/` and does not merge canonical specs.

## Ownership and rollback

`.agents-orchestrator-manifest` owns installed components. `.sdlc-orchestrator-poc-manifest` owns profile selection, prior scalar values, and whether target files existed.

Install rejects invalid, escaping, home, root, source-repository, and worktree targets. Status and uninstall fail closed on manifest tampering. Clean uninstall restores prior values, preserves comments and foreign keys, and removes only empty profile-created paths.

Optional Homebrew installation runs after the OpenCode sync. Missing Homebrew or formula failures warn without rolling back the profile.

## Verification

Free deterministic checks:

```bash
scripts/test-sdlc-orchestrator-contracts.sh
scripts/test-plan-sdd-contracts.sh
scripts/test-sdlc-orchestrator-poc.sh
scripts/test-external-plugin-install.sh contracts
scripts/validate-harness.sh
```

Paid model-backed proof runs exactly one Plan-to-SDD workflow and one Lite workflow, without retries:

```bash
SDLC_POC_E2E_CONFIRM=run-exactly-two-paid-workflows \
  OPENCODE_BIN=/absolute/path/to/opencode \
  scripts/test-sdlc-orchestrator-e2e.sh
```

The recorded 2026-08-06 run on OpenCode 1.18.10 passed both workflows with zero retries. Its ignored evidence path is `.ai/evidence/sdlc-orchestrator-poc/20260806T074118Z/`; this historical result does not prove the current checkout.

## Limits

- Routing is model behavior constrained by contracts, not a static parser.
- Learning remains outside this profile.
- Same-child continuation depends on Task ids; artifacts support new-session recovery.
- Ambiguous active changes require an exact path.
- Manifest-owned config edits block status or uninstall until resolved.
- This is a reversible project profile, not a global migration.
