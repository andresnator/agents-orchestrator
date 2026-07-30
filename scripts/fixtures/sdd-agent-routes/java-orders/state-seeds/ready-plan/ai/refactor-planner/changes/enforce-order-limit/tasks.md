# Tasks: Enforce a maximum line count per order

## Review Workload Forecast

| Field | Value |
| --- | --- |
| Estimated changed lines | 70 |
| Suggested split | none |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: stacked-to-main
400-line budget risk: Low
Shared hotspots: none

## 1. Exception type

Files: src/main/java/com/example/orders/

- [ ] 1.1 Add `OrderLimitExceededException` in `src/main/java/com/example/orders/OrderLimitExceededException.java` as an unchecked exception carrying the offending line count and the maximum.

## 2. Guard

Files: src/main/java/com/example/orders/Order.java

- [ ] 2.1 Add a `MAX_LINES` constant to `Order` and reject construction above it by throwing `OrderLimitExceededException`.

## 3. Tests

Files: src/test/java/com/example/orders/

- [ ] 3.1 Add `OrderLimitTest` in `src/test/java/com/example/orders/OrderLimitTest.java` covering the three spec scenarios: at the maximum, above the maximum, and empty.
