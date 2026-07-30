# Delta for order-limits

## ADDED Requirements

### Requirement: Maximum lines per order

The system MUST reject an order built with more than the documented maximum number
of lines, and MUST accept an order at exactly that maximum.

#### Scenario: Order within the limit is accepted

- **WHEN** an order is constructed with a number of lines at or below the maximum
- **THEN** the order is created
- **AND** its line count equals the number of lines supplied

#### Scenario: Order above the limit is rejected

- **WHEN** an order is constructed with more lines than the maximum
- **THEN** construction fails with the order-limit exception
- **AND** the failure message names the maximum

#### Scenario: Empty order is unaffected

- **WHEN** an order is constructed with no lines
- **THEN** the order is created
