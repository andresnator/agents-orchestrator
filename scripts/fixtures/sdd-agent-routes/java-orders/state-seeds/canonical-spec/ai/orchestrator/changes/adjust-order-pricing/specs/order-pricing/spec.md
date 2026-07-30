# Delta for order-pricing

## ADDED Requirements

### Requirement: Discount share per line

The system MUST be able to report a discount as an even share per order line,
expressed at the monetary scale.

#### Scenario: Discount split across lines

- **WHEN** a discount is shared across the lines of an order
- **THEN** each line receives the discount divided by the number of lines
- **AND** the share is expressed with two decimals, rounded half up

## MODIFIED Requirements

### Requirement: Bulk discount

The system MUST apply a five percent discount to the subtotal of any order whose
subtotal reaches one hundred units, and MUST apply no discount below that amount.

(Previously: the threshold was stated only as "the bulk threshold" without a value)

#### Scenario: Subtotal below one hundred

- **WHEN** the subtotal is below one hundred units
- **THEN** no discount is applied

#### Scenario: Subtotal at one hundred

- **WHEN** the subtotal is exactly one hundred units
- **THEN** the five percent discount is applied

## REMOVED Requirements

### Requirement: Legacy leaflet rounding

(Reason: no code implements it and the paper catalogue was discontinued)
(Migration: None)

## RENAMED Requirements

### Requirement: Money scale → Monetary rounding

(Reason: the rule is about rounding policy, not about a scale field)
(Migration: references in design notes and test names to update)
