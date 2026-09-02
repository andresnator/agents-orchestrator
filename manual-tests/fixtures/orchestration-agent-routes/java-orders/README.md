# java-orders manual fixture

Copy this throwaway Maven project outside the repository before running Plan or Orchestration manual cases. No automated runner consumes it; the person executing a case selects the primary, supplies the prompt, observes worker activity, and inspects final files and hidden `.ai/` state.

The relevant cases live in [Plan manual tests](../../../../domains/plan/manual-tests.md) and [Orchestration manual tests](../../../../domains/orchestration/manual-tests.md). Execution ends with Orchestraitor verification; any later review selects `review-coordinator` independently.

The project is intentionally small, so a human can establish the baseline quickly with a warm Maven cache.

```
pom.xml                                   Java 17, JUnit Jupiter 5.12.2, surefire 3.5.4
src/main/java/com/example/orders/         Order, OrderLine, OrderPricing
src/test/java/com/example/orders/         OrderPricingTest (3 passing tests)
state-seeds/<seed>/                       plan or canonical state for one scenario
```

Before a case, run `mvn -o test` from the copied directory and expect 3 tests with 0 failures.

## Seeds

A seed is state that must exist before a case runs. Copy `state-seeds/<seed>/ai/` to the disposable project's `.ai/` directory.

Seed state uses `ai/`, not `.ai/`, because the repository ignores `.ai/`. The person preparing the disposable project restores the dot.

| Seed | Feeds | Content |
| --- | --- | --- |
| `complex-plan` | `MT-ORCHESTRATION-SDD-CONFIRM`, `MT-ORCHESTRATION-SDD-COMPLETE` | One neutral plan with dependent groups and canonical behavior. |
| `canonical-spec` | `MT-ORCHESTRATION-SDD-COMPLETE` | Existing order-pricing behavior under `.ai/orchestration/specs/`. |

## Changing the fixture

Keep plan evidence and file paths aligned with the Java sources. Update the canonical seed and the existing coverage key when `OrderPricing` behavior changes.
