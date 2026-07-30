# Tasks: Document the discount share and retire leaflet rounding

## Review Workload Forecast

| Field | Value |
| --- | --- |
| Estimated changed lines | 0 |
| Suggested split | none |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: stacked-to-main
400-line budget risk: Low
Shared hotspots: none

## 1. Reconciliation

Files: .ai/orchestrator/changes/adjust-order-pricing/specs/

- [x] 1.1 Confirm against `src/main/java/com/example/orders/OrderPricing.java` that the bulk discount, the per-line share, and the two-decimal money scale are implemented as described.
- [x] 1.2 Confirm no production or test source references leaflet rounding.

## 2. Tests

Files: src/test/java/com/example/orders/

- [x] 2.1 Run the existing suite unchanged to prove this change is specification-only.
