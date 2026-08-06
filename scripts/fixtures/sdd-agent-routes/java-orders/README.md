# java-orders fixture

The throwaway project copied by both real-model runners: the component-level
`scripts/test-sdd-flows.sh` and the profile-level
`scripts/test-sdlc-orchestrator-e2e.sh`. The latter enters through the project-default
`sdlc-orchestrator`, while the former can drive a coordinator directly for focused
scenarios. Executable scenario ids refer to `docs/sdd-test-plan.md`; hypothetical Plan
prompts and expected evidence live in `docs/plan-flow-test-scenarios.md`.

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
| `ready-plan` | SDD-ADOPT-01 | One protected ready `change.md` at `ai/deep-planner/changes/enforce-order-limit/`. It has no execution-choice line; SDD adds that line in place and keeps the producer root. |
| `canonical-spec` | SDD-ARCH-01, SDD-ARCH-02 | A canonical `ai/orchestrator/specs/order-pricing/spec.md` plus a completed `change.md`. Its behavior rows cover ADD, MODIFY, REMOVE, and RENAME so one archive run exercises canonical reconciliation. |
| `legacy` | SDD-MIG-01 | A pre-`.ai/` `orchestraitor/` tree containing one canonical spec and one `change.md`. The storage location is legacy; the change document already uses the current one-file shape. |

Three more seeds are named in the test plan but not populated yet, because no
automated scenario consumes them: `resume-full` (a half-implemented
`add-percentage-coupons` change plus the matching partial `src/`), `resume-light` (a
half-implemented light `normalize-order-reference` change), and `verify-gap` (an
`enforce-positive-quantity` change whose tasks are all checked but whose code does
not satisfy one spec scenario, so `sdd-verify` must report a gap). Those scenarios
stay manual until a runner case needs them.

## Changing the fixture

The pricing behavior is load-bearing for `canonical-spec`: its `change.md` states
that the bulk discount, per-line share, and monetary rounding already exist. Update
the seed if `OrderPricing` changes.
