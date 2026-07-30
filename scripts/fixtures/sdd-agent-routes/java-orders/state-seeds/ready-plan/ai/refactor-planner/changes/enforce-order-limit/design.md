# Design: Enforce a maximum line count per order

## Context

`Order` is a final class with a single constructor that copies the incoming list
(`src/main/java/com/example/orders/Order.java`). It is the only construction path
in the codebase, so a guard there covers every caller.

## Decisions

| Decision | Choice | Why |
| --- | --- | --- |
| Where to guard | The `Order` constructor | The only construction path; nothing can bypass it. |
| Failure mode | Unchecked domain exception | Matches `Objects.requireNonNull` already used there; callers are not expected to recover. |
| Limit value | `MAX_LINES = 500` | Two orders of magnitude above any real fixture, low enough to stop runaway imports. |
| Exception type | New `OrderLimitExceededException` | A named type lets callers distinguish it from a generic argument error. |

## Alternatives Considered

- A separate validator class: rejected, it can be skipped by constructing `Order` directly.
- A checked exception: rejected, it would change every existing call site's signature.

## Risks

- The constant is a policy value with no product owner yet. Documented in the spec
  so a later change to it is a visible spec change, not a silent edit.
