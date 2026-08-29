# Plan: Adjust order pricing contracts

## Outcome

Expose per-line discount reporting while preserving subtotal and money rounding behavior.

## Scope

- In: pricing behavior, focused tests, and canonical order-pricing requirements.
- Out: coupon storage and external exchange rates.

## Evidence

- `src/main/java/com/example/orders/OrderPricing.java`: pricing implementation.
- `src/test/java/com/example/orders/OrderPricingTest.java`: current behavior checks.
- Toolchain: Java 17, JUnit Jupiter 5.12.2, Maven Surefire 3.5.4.

## Behavior

### ADD order-pricing/per-line-discount

- WHEN an order receives the bulk discount.
- THEN each line exposes its proportional discount share.

## Approach

Add focused protection before changing the public pricing result. Preserve two-decimal half-up rounding.

## Work groups

### Group 1: Protect current pricing

Files: src/test/java/com/example/orders/OrderPricingTest.java
Skills: code-conventions, java-testing, behavior-characterization
Depends on: none

- [ ] Add focused subtotal, threshold, and rounding scenarios.

### Group 2: Expose per-line discounts

Files: src/main/java/com/example/orders/OrderPricing.java, src/test/java/com/example/orders/OrderPricingTest.java
Skills: code-conventions, java-testing
Depends on: Group 1

- [ ] Add the public result and verify proportional rounding.

## Dependencies

- Group 2 depends on Group 1.

## Files

- `src/main/java/com/example/orders/OrderPricing.java`: pricing behavior.
- `src/test/java/com/example/orders/OrderPricingTest.java`: protection and new scenarios.

## Skills

- Group 1: code-conventions, java-testing, behavior-characterization.
- Group 2: code-conventions, java-testing.

## Verify

- `mvn -o test`

## Risks and open questions

- Proportional shares must sum to the existing total discount after rounding.

## Execution guidance

Route: SDD
Reason: The public contract and dependent work groups need durable verification and canonical merge.
Run: `ejecuta el plan .ai/deep-planner/plans/adjust-order-pricing.md`
