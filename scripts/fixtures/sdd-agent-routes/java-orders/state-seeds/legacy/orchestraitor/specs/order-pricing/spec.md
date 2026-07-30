# order-pricing

## Requirement: Order subtotal

The system MUST compute an order subtotal as the sum of every line total, where a
line total is the unit price multiplied by the quantity.

### Scenario: Multiple lines

- **WHEN** an order carries more than one line
- **THEN** the subtotal equals the sum of the line totals

### Scenario: Empty order

- **WHEN** an order carries no lines
- **THEN** the subtotal is zero

## Requirement: Bulk discount

The system MUST apply a five percent discount to the subtotal of any order whose
subtotal reaches the bulk threshold, and MUST apply no discount below it.

### Scenario: Subtotal below the threshold

- **WHEN** the subtotal is below the bulk threshold
- **THEN** no discount is applied

### Scenario: Subtotal at the threshold

- **WHEN** the subtotal is exactly the bulk threshold
- **THEN** the five percent discount is applied

## Requirement: Legacy leaflet rounding

The system MUST round every printed leaflet price down to the nearest whole unit
before rendering it on the paper catalogue.

### Scenario: Fractional leaflet price

- **WHEN** a leaflet price carries a fractional part
- **THEN** the printed price is the whole-unit floor

## Requirement: Money scale

The system MUST express every monetary result with two decimal places, rounding
half up.

### Scenario: Result with more precision than the money scale

- **WHEN** a computed amount carries more than two decimals
- **THEN** the returned amount has exactly two decimals, rounded half up
