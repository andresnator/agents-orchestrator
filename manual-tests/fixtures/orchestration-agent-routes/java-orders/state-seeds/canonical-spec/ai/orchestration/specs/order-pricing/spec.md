# Order Pricing

## Requirement: Order subtotal

The system MUST compute the subtotal as the sum of every line total.

### Scenario: Multiple lines

- **WHEN** an order has multiple lines.
- **THEN** the subtotal equals their line-total sum.

## Requirement: Money scale

The system MUST return monetary results with two decimal places and half-up rounding.

### Scenario: Extra precision

- **WHEN** a result has more than two decimals.
- **THEN** the result is rounded half up to two decimals.
