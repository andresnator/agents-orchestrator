# Checkout capability

## ADDED Requirements

### Requirement: Complete checkout total

The system MUST combine tax, discount, and shipping for a valid order and MUST reject an order with no items.

#### Scenario: Valid checkout

- **WHEN** subtotal is 100 and item count is 2
- **THEN** the checkout total is 117

#### Scenario: Empty checkout

- **WHEN** item count is zero
- **THEN** checkout rejects the order
