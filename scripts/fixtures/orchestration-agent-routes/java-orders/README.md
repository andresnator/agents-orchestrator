# java-orders fixture

This throwaway project supports the model-backed orchestration runners. `scripts/test-orchestration-flows.sh` drives focused scenarios, while `scripts/test-multi-primary-e2e.sh` switches between selected primaries.

Scenario contracts live in `docs/plan-flow-test-scenarios.md` and `docs/orchestration-test-plan.md`.

This is a real Maven project because direct execution and SDD workers run the build. The fixture is intentionally small, so `mvn -o test` finishes quickly with a warm `~/.m2`.

```
pom.xml                                   Java 17, JUnit Jupiter 5.12.2, surefire 3.5.4
src/main/java/com/example/orders/         Order, OrderLine, OrderPricing
src/test/java/com/example/orders/         OrderPricingTest (3 passing tests)
state-seeds/<seed>/                       plan or canonical state for one scenario
```

Baseline check, from this directory: `mvn -o test` → `Tests run: 3, Failures: 0`.

## Seeds

A seed is state that must exist before a scenario runs. The runner copies `state-seeds/<seed>/ai/` to `<scratch>/.ai/`.

Seed state uses `ai/`, not `.ai/`, because the repository ignores `.ai/`. The runner restores the dot in scratch state.

| Seed | Feeds | Content |
| --- | --- | --- |
| `complex-plan` | SDD-CONFIRM-01, SDD-COMPLETE-01 | One neutral plan with dependent groups and canonical behavior. |
| `canonical-spec` | SDD-COMPLETE-01 | Existing order-pricing behavior under `.ai/orchestration/specs/`. |

## Changing the fixture

Keep plan evidence and file paths aligned with the Java sources. Update the canonical seed when `OrderPricing` behavior changes.
