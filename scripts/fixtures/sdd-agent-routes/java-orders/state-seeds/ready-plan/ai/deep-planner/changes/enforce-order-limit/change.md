Status: ready-for-sdd | Source: deep-planner

# Change: Enforce a maximum line count per order

## Outcome

Reject malformed imports that create unbounded orders, while preserving all
current pricing behavior and valid order construction.

## Scope

- In: the `Order` construction boundary, a named exception, and focused tests.
- Out: pricing behavior, persistence, and transport validation.

## Behavior

- ADD — Maximum lines per order
  - WHEN an order has at most 500 lines
  - THEN construction succeeds
  - WHEN an order has more than 500 lines
  - THEN construction fails with `OrderLimitExceededException` and names the maximum
- ADD — Empty order remains valid
  - WHEN an order has no lines
  - THEN construction succeeds

## Approach

- Add a public `MAX_LINES = 500` policy constant to `Order` and enforce it in
  the constructor, the only construction path.
- Add an unchecked `OrderLimitExceededException` so callers can identify the
  failure without changing every signature.

## Work

### 1. Exception

Files: src/main/java/com/example/orders/OrderLimitExceededException.java

- [ ] 1.1 Add the exception with the offending count, maximum, and clear message.

### 2. Guard

Files: src/main/java/com/example/orders/Order.java

- [ ] 2.1 Add `MAX_LINES` and reject construction above it.

### 3. Tests

Files: src/test/java/com/example/orders/OrderLimitTest.java

- [ ] 3.1 Cover the maximum, above the maximum, and empty-order cases.

## Verify

- `mvn -q test`

## Risks / Open questions

- `500` is a provisional policy value; changing it later remains an explicit behavior change.
