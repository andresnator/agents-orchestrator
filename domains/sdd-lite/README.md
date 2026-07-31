# SDD Lite Domain (POC)

A deliberate proof of concept, not a replacement for the `sdd` domain. One primary agent, `orchestralite`, runs the whole flow for a bounded change in a single context — interview, `change.md` drafted and corrected in chat, inline implementation — and delegates exactly one step: the cold verification, to `lite-verify`.

## Hypothesis under test

The PR #30 context-diet measurements (96:1 read-to-delegate ratio, 25 silent compaction passes) covered the full orchestraitor under mixed use, and moved light-depth drafting *into* a subagent. This POC probes the case that measurement did not cover: a dedicated agent, a genuinely bounded change, a single session. The claim: total inline cost < total delegated depth-light cost, with zero compaction passes and the same verify outcome. Secondary claim: a distilled contract embedded in the agent prompt replaces the drafting skill for a frontier model — `orchestralite` loads no skills and carries its `change.md` template inline.

## Experiment status: hypothesis supported at equal coverage (2026-07-30)

Two paired runs on the `java-orders` fixture. Each pair uses a byte-identical prompt for both agents, the same working tree, and the fixture reset to baseline between runs; both agents run the same model per role (`gpt-5.6-sol` for the primary and for drafting, `gpt-5.6-luna` for implement/verify).

### Run 2 — `allocateDiscount`, coverage pinned in the prompt

The task: replace `OrderPricing.discountPerLine` with `allocateDiscount(Order, BigDecimal)` returning per-line shares proportional to `lineTotal()` that sum exactly to the input discount, with a deterministic rounding remainder. The prompt enumerates **exactly five scenarios**, which removes the coverage confound of run 1. No reasoning variants are pinned on either side, so the drafting step runs at the same default for both flows.

| | depth light (`orchestraitor`) | lite (`orchestralite`) | delta |
|---|---|---|---|
| Total tokens | 1,577,058 | 800,624 | **−49%** |
| Fresh input | 209,953 | 91,999 | −56% |
| Cache read | 1,350,144 | 699,392 | −48% |
| Output | 10,584 | 6,749 | −36% |
| Reasoning | 6,377 | 2,484 | −61% |
| Subagent sessions | 4 | 1 | −75% |
| Primary turns | 19 | 21 | +11% |
| Primary context peak | 39,473 | 36,634 | −7% |
| Compaction passes | 0 | 0 | tie |
| Wall clock | 464 s | 270 s | −42% |
| Scenarios drafted / tests | 5 / 8 | 5 / 8 | tie |
| Verify | ALL PASS 5/5 | ALL PASS 5/5 | tie |

Coverage came out equal by construction, and the deliverables are behaviourally equivalent: each implementation passes the *other* run's test suite, 8/8 in all four impl×tests combinations, verified with an independent `mvn -o test`. Both converged on the same algorithm — proportional shares at `RoundingMode.DOWN`, residue to the largest line, ties to the lowest index.

Two asymmetries survive, and they point in opposite directions:

- **Robustness, in lite's favour.** On an order whose lines all have a zero `lineTotal()` — a case neither the prompt nor either spec names — the light implementation throws `ArithmeticException: / by zero`; the lite implementation guards `subtotal.signum() == 0` and returns zeroed shares. Confirmed by running an adversarial test against both.
- **Durable record, in light's favour.** SDD merged a canonical `specs/order-pricing/spec.md`; lite keeps only the archived `change.md`. That is by design, and it is the real trade the domain makes.

One reproducible defect surfaced on the SDD side, unrelated to the comparison: both light runs wrote `TDD: no` in the `change.md` header although the prompt asked for tests alongside. Lite recorded `TDD: alongside` correctly in both runs.

### Run 1 — `totalQuantity`, coverage not pinned

| | depth light | lite | delta |
|---|---|---|---|
| Total tokens | 1,278,978 | 1,007,133 | −21% |
| Subagent sessions | 4 | 1 | −75% |
| Primary context peak | 37,959 | 37,346 | ≈ equal |
| Compaction passes | 0 | 0 | tie |
| Wall clock | 383 s | 272 s | −29% |
| Scenarios drafted / tests | 2 / 2 | 1 / 1 | — |

Inconclusive on its own terms: the prompt named no edge case, light drafted an extra scenario lite did not, so the −21% bought less work. Run 2 exists to remove exactly that confound.

### Reading

At equal, verified coverage the single-context flow cost **half** the delegated flow for a bounded change, with no compaction and a slightly lower context peak. The saving is not in the model doing less thinking — it is in not re-establishing context four times: SDD's four subagents each pay a fresh read of the same two files, and that shows up as −48% cache read and −75% delegation sessions.

The scope of the claim stays narrow. Both tasks fit in two files, which is the regime the domain is gated to; nothing here says anything about a change that outgrows the scope gate, where the delegation the lite flow avoids is precisely the mechanism that prevents the compaction freeze. What is now established is that inside the gate, delegation is overhead rather than insurance — and that the flow's own gate is what keeps that true.

## Where the tokens actually went (2026-07-30, after run 2)

Run 2 was profiled per tool call and per turn to find out what to cut. The answer was not what the flow *does* — it was what it carries.

**The fixed preamble dominates.** The lite primary opened at a 23,863-token floor and peaked at 36,634. Everything the session actually did — interview, draft, reads, implementation, tests, verify — added ~12,700 tokens. The rest is a fixed preamble re-sent on each of 21 turns, which is ~63% of the run. Cost is therefore `floor × turns`, and both factors are addressable.

**The skill catalogue was the single biggest line item.** OpenCode advertises every installed skill's name and description in the system prompt of every turn (`SystemPrompt.skills` → `skill.available(agent)`), filtered per agent by `Permission.evaluate("skill", …)`. `orchestralite` is designed to load no skills at all and was carrying all 84.

Measured with a one-turn probe on a trivial prompt, before and after adding `permission.skill` allowlists (and `todowrite: deny` on the lite side):

| Agent | Floor before | Floor after | Delta |
|---|---|---|---|
| `orchestralite` | 23,578 | 13,249 | **−10,329 (−44%)** |
| `orchestraitor` | 28,275 | 19,970 | **−8,305 (−29%)** |

Almost all of it is the catalogue: `orchestraitor` keeps `todowrite` and the Graphify tools and still drops 8,305 by allowlisting 4 skills. The floor moving at all also confirms that `deny` removes a tool from the prompt rather than refusing it at call time — a gated tool would still cost its schema.

Two decisions hide in that number and only the first produced it. The −10,329 comes from denying the 83 skills the agent never used; an allowlist keeping one skill would have measured the same. Embedding the 84th (`code-conventions`) is a separate, smaller call: the distilled copy costs ~340 tokens on every one of 21 turns (~7.1k), versus ~906 tokens loaded at turn ~2 and re-sent for the remaining ~19 (~17.2k) plus the turn the `skill` call itself spends. Embedding wins only for content the flow uses on every run — which the scope gate guarantees here. It does not generalize to `sdd`, whose drafting skills are per-phase and situational.

**Graphify is a net loss inside the scope gate, measured.** The Graphify MCP servers (local plus global) cost **1,363 tokens per turn** in advertised tool schemas — isolated by probing with them enabled and disabled. The entire run-2 lite session read 4 files, 3,360 characters (~840 tokens), so for a change bounded to two files a graph cannot repay more than ~840 tokens against ~28,600 over 21 turns. `orchestralite` and `lite-verify` therefore carry `graphify*: deny`; an agent-level deny measures identical to disabling the servers outright, so the saving is real and not merely unused capacity. This says nothing about `orchestraitor` or about changes that outgrow the gate, where exploration is genuine work and the graph has something to save — the sdd agents keep their Graphify access. Both lite agents also override the global Graphify-first precedence rule locally (an absent graph is the expected state, never friction), and change lookups are existence-guarded: a missing `<change>` becomes a question to the user (orchestralite) or a `blockers` entry (lite-verify), never a raw tool error.

**Printed test output was not the problem.** The whole run produced 5,858 characters of command output across 10 bash calls (~1,500 tokens), 87% of it from a single red `mvn` in the TDD phase; the green runs returned 11 characters each because the agent already used `-q`. Persisting for ~11 turns that is ~2% of the run. The mechanism is real — output enters the context and is re-sent forever — but the magnitude here was small, so the agent gets a cheap discipline rule (quiet flag, bounded tail, failing-subset re-runs) as insurance for runs that cycle in red, not as a headline saving.

**Turn count is the other multiplier.** Each turn re-sent ~33k tokens. The run spent 5 `todowrite` calls maintaining a second task list next to the `change.md` checkboxes that are already the ledger, and re-ran an already-green suite twice. Both are now closed off in the agent contract.

Changes applied: `permission.skill` allowlists across sdd-lite and sdd, `todowrite: deny` and `graphify*: deny` plus an embedded copy of the code conventions in `orchestralite` (restoring the domain's zero-skill claim, which one `skill` call had quietly broken), command-output discipline, and validation once per task group.

**What is not measured:** only the floor. At run 2's 21 turns the floor cut projects to roughly −217k tokens (~27% of 800,624), but the turn count is a second variable that the `todowrite` and validation rules also move, and no paired run has been repeated since. Treat the end-to-end effect as open.

One correctness fix came out of the same profiling, and it applies to both domains: in *both* run-2 flows the verify receipt came back malformed and had to be re-delegated — `sdd-verify` omitted the terminal `VERIFY: ALL PASS` line and reported unrelated pre-existing working-tree files as gaps. The terminal line is now the first line of the receipt template instead of a rule stated in prose after it, and both verify agents are told that paths outside the brief's declared scope are invisible, never gaps.

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (primary) | `orchestralite` | Runs the bounded single-context lite flow end to end |
| Agent (subagent) | `lite-verify` | Cold-checks the implementation against `change.md` scenarios |

`lite-verify` is a trimmed fork of the sdd domain's `sdd-verify` agent (author: andresnator, this repository); it is duplicated rather than shared so the domain installs standalone and the experiment stays decoupled from `sdd`.

The domain is self-contained: no skills, no commands, no dependency on the `sdd` domain being installed. `orchestralite` loads no skills at all — the `skill` tool is fully denied — and instead carries two contracts embedded in its prompt: the `change.md` template (a distilled mirror of `skills/sdd-draft-light/SKILL.md`) and the code conventions (a distilled mirror of `skills/code-conventions/SKILL.md`). That duplication is deliberate and has a maintenance cost: editing either skill does **not** propagate here, and `scripts/validate-harness.sh` does not detect the drift — whoever edits those skills must review the embedded copies. If the agent ever needs non-embedded skill content, it can still read `skills/<name>/SKILL.md` as a plain file.

## Flow

```
interview -> change.md in chat -> approval -> write file -> implement inline -> lite-verify (cold) -> fix (max 1 round) -> archive
```

Hard boundaries, enforced by a scope gate at entry and mid-flight:

- Bounded changes only: ~5 files or fewer, no sprawling new capability, low risk. Anything larger is redirected to the `orchestraitor` with full SDD; the drafted `change.md` may seed its interview but is never presented as a ready-for-sdd bundle (`docs/plan-handoff.md` forbids the single-file shape as a handoff format).
- State lives under `.ai/sdd-lite/` — never `.ai/orchestrator/`, so the SDD discovery scan is never confused by lite changes.
- No canonical specs and no spec merge at archive; the archived `change.md` is the whole record.
- Verification is always delegated and always cold — the one part of the flow where a fresh context is the point, not an overhead.

## Testing

Flow scenarios (`LITE-*`) reuse the `scripts/fixtures/sdd-agent-routes/java-orders/` fixture; see `docs/sdd-test-plan.md`. Like the sdd flow scenarios, they call a real model and spend credits, so they are opt-in and not wired into `scripts/validate-harness.sh`.
