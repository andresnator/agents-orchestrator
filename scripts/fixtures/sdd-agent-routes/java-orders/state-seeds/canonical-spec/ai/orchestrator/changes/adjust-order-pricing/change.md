Status: active | Source: orchestraitor
Mode: automatic | TDD: alongside | Judgment: none | Delivery: none

# Change: Document discount sharing and retire leaflet rounding

## Outcome

Make the canonical `order-pricing` spec match shipped, tested behavior without
changing production code.

## Scope

- In: canonical `order-pricing` behavior reconciliation.
- Out: any production behavior change.

## Behavior

- ADD — Discount share per line
  - WHEN a discount is shared across an order's lines
  - THEN each line receives the discount divided by the line count at two-decimal half-up rounding
- MODIFY — Bulk discount
  - WHEN the subtotal is below one hundred units
  - THEN no discount is applied
  - WHEN the subtotal is at least one hundred units
  - THEN a five percent discount is applied
- REMOVE — Legacy leaflet rounding
  - WHEN canonical behavior is merged
  - THEN the unsupported paper-catalogue rule is absent
- RENAME — Money scale -> Monetary rounding
  - WHEN canonical behavior is merged
  - THEN the unchanged two-decimal half-up rule uses the new requirement name only

## Approach

- Reconcile the canonical spec to `OrderPricing`, which already implements the
  bulk discount, per-line share, and two-decimal half-up rounding.

## Work

### 1. Reconciliation

Files: .ai/orchestrator/specs/order-pricing/spec.md

- [x] 1.1 Confirm the bulk discount, per-line share, and monetary rounding in production code.
- [x] 1.2 Confirm no production or test source references leaflet rounding.

### 2. Tests

Files: src/test/java/com/example/orders/OrderPricingTest.java

- [x] 2.1 Run the existing suite unchanged.

## Verify

- `mvn -q test`
