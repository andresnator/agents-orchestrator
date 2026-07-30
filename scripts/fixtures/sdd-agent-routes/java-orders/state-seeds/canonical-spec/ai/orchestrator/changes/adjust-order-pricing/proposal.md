Mode: automatic | TDD: tests alongside | Judgment: none | Depth: full | Delivery: none

# Proposal: Document the discount share and retire leaflet rounding

## Why

The canonical `order-pricing` spec still describes a paper-catalogue rounding rule
that no code implements, and it does not describe how a bulk discount is reported
per line even though `OrderPricing.discountPerLine` has shipped. The spec and the
code have drifted in both directions, so the canonical document cannot be trusted
as the current behavior of the system.

## What Changes

- The per-line discount share becomes a stated requirement.
- The bulk discount requirement is restated to name the threshold explicitly.
- The leaflet rounding requirement is dropped; nothing implements it.
- The money-scale requirement is renamed to monetary rounding, unchanged in substance.

## Capabilities

### Modified

- `order-pricing`: The pricing rules an order goes through before checkout. Creates `specs/order-pricing/spec.md` delta.

## Scope In

- Specification-level reconciliation of `order-pricing`.

## Scope Out

- Any behavior change in `OrderPricing`; the code is already correct.

## Risks

- Removing a requirement that some downstream consumer still assumes. Mitigated by
  the Reason and Migration notes on the REMOVED entry.

## Success Criteria

- [ ] The canonical spec describes the per-line discount share.
- [ ] The canonical spec no longer mentions leaflet rounding.
- [ ] The existing pricing tests pass unchanged.
