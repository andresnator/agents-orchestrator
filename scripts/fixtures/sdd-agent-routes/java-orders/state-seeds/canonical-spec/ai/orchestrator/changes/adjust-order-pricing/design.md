# Design: Document the discount share and retire leaflet rounding

## Context

`OrderPricing` (`src/main/java/com/example/orders/OrderPricing.java`) already
implements the bulk discount, the per-line share, and the two-decimal money scale.
No production code references leaflet rounding.

## Decisions

| Decision | Choice | Why |
| --- | --- | --- |
| Direction of reconciliation | Spec follows code | The code is the shipped, tested behavior. |
| Leaflet rounding | REMOVED, not MODIFIED | Nothing implements it and no caller asks for it. |
| Money scale | RENAMED, not rewritten | The substance is unchanged; only the name misleads. |

## Alternatives Considered

- Implementing leaflet rounding to match the spec: rejected, there is no consumer.

## Risks

- None at the code level; this change is specification-only.
