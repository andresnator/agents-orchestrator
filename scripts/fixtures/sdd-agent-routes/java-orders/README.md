# java-orders fixture

The throwaway project the SDD flow runner (`scripts/test-sdd-flows.sh`) copies into
a scratch directory before driving `orchestraitor` headlessly. Scenario ids refer to
`docs/sdd-test-plan.md`.

It is a real Maven project on purpose: `sdd-implement` and `sdd-verify` run a build,
so the fixture has to compile and have a suite that passes before any change lands.
It is deliberately tiny — three classes and three tests — so a full `mvn -o test`
finishes in about a second on a warm `~/.m2`.

```
pom.xml                                   Java 17, JUnit Jupiter 5.12.2, surefire 3.5.4
src/main/java/com/example/orders/         Order, OrderLine, OrderPricing
src/test/java/com/example/orders/         OrderPricingTest (3 passing tests)
state-seeds/<seed>/                       pre-existing state a scenario starts from
```

Baseline check, from this directory: `mvn -o test` → `Tests run: 3, Failures: 0`.

## Seeds

A seed is the state a scenario needs to already exist before the agent runs. The
runner copies `state-seeds/<seed>/ai/` to `<scratch>/.ai/` and `state-seeds/<seed>/src/`
over the project's `src/`, then starts the session.

**Seed state lives under `ai/`, not `.ai/`** — the repo's `.gitignore` swallows `.ai/`
anywhere in the tree, so a dot-named seed directory would be untracked and the fixture
would silently ship empty. The un-dotting is purely a storage concern; the runner
restores the dot.

| Seed | Feeds | Content |
| --- | --- | --- |
| `ready-plan` | SDD-ADOPT-01…05 | A complete ready-for-sdd bundle at `ai/refactor-planner/changes/enforce-order-limit/`. `proposal.md` line 1 is exactly `Status: ready-for-sdd | Source: refactor-planner`, with no kickoff line — adoption has to write it. `tasks.md` carries the five forecast guard lines plus `Files:` and `Depends on:` per group. All three task groups are unchecked, so adoption runs from implement onward. |
| `canonical-spec` | SDD-ARCH-01, SDD-ARCH-02 | A canonical `ai/orchestrator/specs/order-pricing/spec.md` plus a finished change at `ai/orchestrator/changes/adjust-order-pricing/` whose every task is `[x]`, so the session goes straight to archive. Its delta covers all four operations — ADDED (`Discount share per line`), MODIFIED (`Bulk discount`), REMOVED (`Legacy leaflet rounding`) and RENAMED (`Money scale → Monetary rounding`) — which is what lets one archive run feed both the positive merge test and the RENAMED negative. The change is specification-only: the code already implements everything the delta describes, so nothing needs implementing before the merge. |
| `legacy` | SDD-MIG-01 | A pre-`.ai/` `orchestraitor/` tree — the runner drops it at the project root as `.orchestraitor/` rather than under `.ai/`. Holds a canonical spec and one light-depth change so the migration has both file kinds to move. |

Three more seeds are named in the test plan but not populated yet, because no
automated scenario consumes them: `resume-full` (a half-implemented
`add-percentage-coupons` change plus the matching partial `src/`), `resume-light` (a
half-implemented light `normalize-order-reference` change), and `verify-gap` (an
`enforce-positive-quantity` change whose tasks are all checked but whose code does
not satisfy one spec scenario, so `sdd-verify` must report a gap). Those scenarios
stay manual until a runner case needs them.

## Changing the fixture

The pricing behavior is load-bearing for the `canonical-spec` seed: its delta asserts
that the bulk discount, the per-line discount share, and the two-decimal money scale
are implemented as described. Changing `OrderPricing` without updating that seed makes
the archive scenario describe behavior the code no longer has.
