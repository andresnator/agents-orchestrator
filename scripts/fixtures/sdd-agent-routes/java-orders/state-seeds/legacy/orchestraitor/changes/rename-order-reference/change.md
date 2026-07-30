Mode: automatic | TDD: tests alongside | Judgment: none | Depth: light | Delivery: none

# Change: Expose the order reference under a clearer name

## Why / What

`Order.reference()` is the only accessor for the order identifier, and callers read
it as if it were a database id. Rename the accessor to `orderNumber()` so the
domain vocabulary matches how the value is used, keeping the field itself intact.

## Spec Deltas

### order-entry

#### ADDED Requirements

##### Requirement: Order number accessor

The system MUST expose the order identifier through an accessor named for the
order number.

###### Scenario: Reading the identifier

- **WHEN** a caller reads the identifier of an order
- **THEN** the value supplied at construction is returned

## Tasks

- [ ] 1.1 Rename `reference()` to `orderNumber()` in `src/main/java/com/example/orders/Order.java`.
- [ ] 1.2 Update every call site and test reference.
