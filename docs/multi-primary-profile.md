# Run the Multi-Primary Profile

This opt-in project profile installs five direct workflow primaries while preserving the user's selected default agent.

## Quick path

Use an absolute target outside this repository and its worktrees:

```bash
scripts/multi-primary-profile.sh install --project-root /absolute/path/to/project
scripts/multi-primary-profile.sh status --project-root /absolute/path/to/project
scripts/multi-primary-profile.sh uninstall --project-root /absolute/path/to/project
```

Project installs skip Homebrew by default. Add `--install-brew-tools` to install missing profile formulas or `--no-install-brew-tools` to make the skip explicit. Uninstall never removes Homebrew tools.

## Profile and entry points

The profile installs `plan,sdd,architecture,sdd-lite,review,common` into `.opencode/` and applies only:

```jsonc
{
  "subagent_depth": 1
}
```

It never adds, replaces, or removes `default_agent`. Select a primary with Tab or run one of its commands:

| Work | Primary | Commands |
|---|---|---|
| Planning, discovery, or protected refactor | `deep-planner` | `/deep-plan`, `/wayfinder`, `/refactor-plan`, `/harden-plan` |
| Full implementation, handoff, or resume | `orchestraitor` | `/sdd` |
| Bounded low-risk implementation | `orchestralite` | `/sdd-lite` |
| Architecture maps, reviews, or decisions | `architect` | `/arch-map`, `/arch-review`, `/arch-ideate`, `/boundary-inspector` |
| Adversarial or Socratic review | `review-coordinator` | `/judgment`, `/defend` |

The topology is `primary -> worker`. Every primary owns its user-facing questions; workers keep `question: deny` and return evidence to their caller.

## Explicit handoffs

Plan and Architecture Ideate write:

```text
.ai/<producer>/changes/<change>/change.md
```

The first line is `Status: ready-for-sdd | Source: <producer>`. Run `/sdd <exact-change.md-path>` to adopt and execute it in place. Direct SDD uses `.ai/orchestrator/changes/`; Lite uses `.ai/sdd-lite/` and does not merge canonical specs.

When full SDD reaches requested Judgment, complete three primary turns:

1. Let `orchestraitor` persist `Phase: judgment` and report the exact scope.
2. Select `review-coordinator` or run `/judgment [light] <scope>` and retain its ledger or verdict.
3. Select `orchestraitor` again or run `/sdd <active-root>` with that result so SDD re-verifies, merges, and archives.

## Ownership and rollback

`.agents-orchestrator-manifest` owns installed components. `.multi-primary-profile-manifest` owns profile selection, the selected `opencode.jsonc` or `opencode.json` path, the prior `subagent_depth`, and whether target files existed.

Install rejects invalid, escaping, home, root, source-repository, and worktree targets. Status and uninstall fail closed on manifest tampering. Clean uninstall restores the prior depth, preserves `default_agent`, comments, and foreign keys, and removes only empty profile-created paths.

An installed legacy `.sdlc-orchestrator-poc-manifest` must be uninstalled from its original checkout before this profile is installed; the new profile refuses to adopt a foreign installer manifest.

## Verification

Free deterministic checks:

```bash
scripts/test-primary-agent-contracts.sh
scripts/test-plan-sdd-contracts.sh
scripts/test-multi-primary-profile.sh
scripts/test-external-plugin-install.sh contracts
scripts/validate-harness.sh
```

Paid model-backed proof runs direct Plan-to-SDD and Lite workflows without retries:

```bash
MULTI_PRIMARY_E2E_CONFIRM=run-exactly-two-paid-workflows \
  OPENCODE_BIN=/absolute/path/to/opencode \
  scripts/test-multi-primary-e2e.sh
```

Do not infer live model behavior from deterministic contracts. The paid runner is opt-in because it uses real credentials and credits.

## Limits

- Intent classification is explicit: the user selects a primary or command.
- Cross-primary handoffs use exact artifact paths instead of Task ids.
- Learning remains outside this profile.
- Ambiguous active changes require an exact path.
- Manifest-owned config edits block status or uninstall until resolved.
