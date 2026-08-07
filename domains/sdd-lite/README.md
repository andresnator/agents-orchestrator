# SDD Lite Domain (POC)

A bounded implementation flow in one persistent coordinator context. `orchestralite` writes and executes one `change.md`; only cold verification is delegated.

## Quick path

1. Ask for an obviously bounded, low-risk change through `sdlc-orchestrator`.
2. Confirm the retained draft in `.ai/sdd-lite/changes/<change>/change.md` when interactive.
3. Review the implementation, cold verification, and archived `change.md`.

## Scope gate

Use Lite only for changes of roughly five files or fewer with low risk and no sprawling capability. Redirect broader or riskier work to full SDD before implementation. Re-check the gate if scope grows.

```text
sdlc-orchestrator -> orchestralite: draft + implement inline
                  -> lite-verify: cold check
                  -> orchestralite: bounded fix, archive
```

## Deliberate trade-offs

| Lite keeps | Lite omits |
|---|---|
| One durable `change.md` | Canonical spec merge |
| One coordinator context | Implementation fan-out |
| Independent cold verification | Commit-per-wave delivery |
| One bounded fix round | Full adversarial judgment loop |

State stays under `.ai/sdd-lite/`, never `.ai/orchestrator/`. The archived `change.md` is the complete durable record. Missing changes, scope expansion, unsafe operations, or ambiguous verifier output block and return to the primary; they are never guessed.

Lite uses `sdd-execution-skills` while drafting, then loads only each Work group's selected implementation skills; code/test groups always include `code-conventions`. Graphify stays denied. `lite-verify` loads only shared cold verification. Normal profile routing still requires the `sdlc` domain.

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (subagent coordinator) | `orchestralite` | Drafts, implements, fixes, and archives the bounded change |
| Agent (subagent) | `lite-verify` | Cold-checks the implementation against `change.md` |
| Skill | `behavior-characterization` | Captures current behavior when bounded hardening stays Lite-safe |
| Skill | `code-conventions` | Applies repository code and test conventions |
| Skill | `cognitive-doc-design` | Keeps bounded human-facing documentation clear |
| Skill | `java-testing` | Implements focused Java tests |
| Skill | `legacy-code-safety` | Protects bounded behavior-preserving changes |
| Skill | `sdd-cold-verification` | Verifies scoped scenarios independently |
| Skill | `sdd-execution-skills` | Selects implementation skills per Work group |
| Skill | `systematic-debugging` | Applies evidence-first debugging to bounded fixes |

Run the `LITE-*` scenarios through the opt-in flow harness described in [docs/sdd-test-plan.md](../../docs/sdd-test-plan.md).
