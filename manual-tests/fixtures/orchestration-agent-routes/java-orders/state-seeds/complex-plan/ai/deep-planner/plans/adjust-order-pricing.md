# Plan: Adjust order pricing contracts

## Intent

- **Goal:** Expose per-line discount reporting while preserving subtotal and money rounding behavior.
- **Limits:** No coupon storage or external exchange rates.
- **Fails if:** Subtotal or two-decimal half-up rounding changes, or proportional shares do not sum to the total discount.

## Context

- **Reads:**
  - `src/main/java/com/example/orders/OrderPricing.java`: pricing implementation.
  - `src/test/java/com/example/orders/OrderPricingTest.java`: current behavior checks.
  - Toolchain: Java 17, JUnit Jupiter 5.12.2, Maven Surefire 3.5.4.
- **Never reads:** none
- **Persona:** behavior-preserving Java implementer.
- **Scope:**
  - `src/main/java/com/example/orders/OrderPricing.java`: pricing behavior.
  - `src/test/java/com/example/orders/OrderPricingTest.java`: protection and new scenarios.

## Expectations

### Scenarios

#### ADD order-pricing/per-line-discount

- WHEN an order receives the bulk discount.
- THEN each line exposes its proportional discount share.

### Done means

- `mvn -o test`

### Quality needs

- none beyond repository conventions

## Method

### Approach

Add focused protection before changing the public pricing result. Preserve two-decimal half-up rounding.

### Work groups

#### Group 1: Protect current pricing

Files: src/test/java/com/example/orders/OrderPricingTest.java
Skills: oc-conventions, oc-java-test, oc-characterize
Depends on: none

- [ ] Add focused subtotal, threshold, and rounding scenarios.

#### Group 2: Expose per-line discounts

Files: src/main/java/com/example/orders/OrderPricing.java, src/test/java/com/example/orders/OrderPricingTest.java
Skills: oc-conventions, oc-java-test
Depends on: Group 1

- [ ] Add the public result and verify proportional rounding.

### Risks and open questions

- Proportional shares must sum to the existing total discount after rounding.

### Execution guidance

Route: SDD
Reason: The public contract and dependent work groups need durable verification and canonical merge.
Run: `ejecuta el plan .ai/deep-planner/plans/adjust-order-pricing.md`
