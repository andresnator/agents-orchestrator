Status: ready-for-sdd | Source: refactor-planner

# Proposal: Enforce a maximum line count per order

## Why

Orders are built by callers that append lines without any upper bound, so a
malformed import can create an order with thousands of lines. `OrderPricing`
then walks every line on each pricing call, and `discountPerLine` divides by the
line count, so an unbounded order degrades checkout latency with no signal to
the caller. There is no place in the domain today that states how large an order
may be.

## What Changes

- `Order` rejects construction above a documented maximum line count.
- A named domain exception carries the rejection reason to the caller.
- The maximum is a single documented constant, not a literal spread across call sites.

## Capabilities

### New

- `order-limits`: Size boundaries an order must satisfy to exist. Creates `specs/order-limits/spec.md`.

## Scope In

- Rejection at construction time in `Order`.
- The exception type and its message.

## Scope Out

- Pricing behavior; `OrderPricing` is not touched.
- Any persistence or transport-level validation.

## Risks

- Callers that build oversized orders start failing fast. Mitigated by keeping the
  limit high enough that no current test or fixture crosses it.

## Success Criteria

- [ ] An order at the maximum line count is accepted.
- [ ] An order above the maximum is rejected with the named exception.
- [ ] The existing pricing tests still pass unchanged.
