Status: active | Source: orchestraitor
Mode: automatic | TDD: alongside | Judgment: none | Delivery: none

# Change: Expose the order reference under a clearer name

## Outcome

`Order.reference()` is the only accessor for the order identifier, and callers read
it as if it were a database id. Rename the accessor to `orderNumber()` so the
domain vocabulary matches how the value is used, keeping the field itself intact.

## Scope

- In: the `Order` accessor and every call site.
- Out: persistence shape and the stored field name.

## Behavior

- RENAME — Reference accessor -> Order number accessor
  - WHEN a caller reads an order's identifier through `orderNumber()`
  - THEN the value supplied at construction is returned

## Approach

- Rename only the accessor; keep the stored field intact.

## Work

### 1. Rename accessor

Files: src/main/java/com/example/orders/Order.java, src/test/java/com/example/orders/
Skills: code-conventions, legacy-code-safety

- [ ] 1.1 Rename `reference()` to `orderNumber()` and update every call site.

## Verify

- `mvn -q test`
