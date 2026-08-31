Development: alongside
Delivery: working-tree
Baseline: working-tree
Commits: none
Changes: none

# Run: Add order reference label

## Outcome

Expose a stable display label for an order reference.

## Behavior

### ADD order-insights/reference-label

- WHEN an order has reference `ORD-1`.
- THEN `referenceLabel()` returns `Order ORD-1`.

## Work groups

### Group 1: Add the label

Files: src/main/java/com/example/orders/Order.java, src/test/java/com/example/orders/OrderPricingTest.java
Skills: code-conventions, java-testing
Depends on: none

- [ ] Add `Order.referenceLabel()` with focused coverage.

## Dependencies

- None.

## Files

- `src/main/java/com/example/orders/Order.java`: reference label.
- `src/test/java/com/example/orders/OrderPricingTest.java`: focused coverage.

## Skills

- Group 1: code-conventions, java-testing.

## Verify

- `mvn -o test`
