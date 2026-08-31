# Plan: Add order insights

## Outcome

Expose order line count and bulk-discount eligibility as two independently useful public behaviors.

## Scope

- In: `Order` line count, `OrderPricing` eligibility, and focused tests.
- Out: discount calculation changes, persistence, and canonical behavior outside these two requirements.

## Evidence

- `src/main/java/com/example/orders/Order.java`: owns order lines.
- `src/main/java/com/example/orders/OrderPricing.java`: owns the bulk threshold.
- `src/test/java/com/example/orders/OrderPricingTest.java`: current focused pricing checks.
- Toolchain: Java 17, JUnit Jupiter 5.12.2, Maven Surefire 3.5.4.

## Behavior

### ADD order-insights/line-count

- WHEN an order contains several lines.
- THEN `lineCount()` returns their count.

### ADD order-insights/bulk-eligibility

- WHEN an order subtotal reaches the bulk threshold.
- THEN `isBulkDiscountEligible(order)` returns true; below the threshold it returns false.

## Approach

Implement and verify two public behaviors in dependency order. If commit delivery is selected, keep exactly two units in this order and use these exact messages:

1. `unit-01` — `feat(order): expose line count`
2. `unit-02` — `feat(pricing): expose bulk eligibility`

## Work groups

### Group 1: Expose line count

Files: src/main/java/com/example/orders/Order.java, src/test/java/com/example/orders/OrderPricingTest.java
Skills: code-conventions, java-testing
Depends on: none

- [ ] Add `Order.lineCount()` with focused coverage.

### Group 2: Expose bulk eligibility

Files: src/main/java/com/example/orders/OrderPricing.java, src/test/java/com/example/orders/OrderPricingTest.java
Skills: code-conventions, java-testing
Depends on: Group 1

- [ ] Add `OrderPricing.isBulkDiscountEligible(Order)` with threshold and below-threshold coverage.

## Dependencies

- Group 2 depends on Group 1 so its overlapping test-file edit follows the first verified unit.

## Files

- `src/main/java/com/example/orders/Order.java`: line count.
- `src/main/java/com/example/orders/OrderPricing.java`: bulk eligibility.
- `src/test/java/com/example/orders/OrderPricingTest.java`: focused coverage.

## Skills

- Group 1: code-conventions, java-testing.
- Group 2: code-conventions, java-testing.

## Verify

- `mvn -o test`

## Risks and open questions

- Eligibility must reuse the existing threshold comparison so it cannot drift from discount calculation.

## Execution guidance

Route: SDD
Reason: Two dependent public behaviors need durable verification and independent delivery units.
Run: `ejecuta el plan .ai/deep-planner/plans/add-order-insights.md`
