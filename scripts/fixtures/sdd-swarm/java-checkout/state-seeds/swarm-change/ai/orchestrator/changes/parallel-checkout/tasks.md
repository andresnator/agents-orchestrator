# Tasks: Parallel checkout

## Review Workload Forecast

| Field | Value |
| --- | --- |
| Estimated changed lines | 220 |
| Suggested split | none |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low
Shared hotspots: src/main/java/com/example/checkout/CheckoutRegistry.java

## 1. Tax policy

Files: src/main/java/com/example/pricing/TaxCalculator.java, src/test/java/com/example/pricing/TaxCalculatorTest.java
Depends on: none

- [ ] 1.1 Add a 20 percent `TaxCalculator` and its focused test.

## 2. Shipping policy

Files: src/main/java/com/example/shipping/ShippingCalculator.java, src/test/java/com/example/shipping/ShippingCalculatorTest.java
Depends on: none

- [ ] 2.1 Add a base-plus-items `ShippingCalculator` and its focused test.

## 3. Discount policy

Files: src/main/java/com/example/discount/DiscountPolicy.java, src/test/java/com/example/discount/DiscountPolicyTest.java
Depends on: none

- [ ] 3.1 Add a threshold `DiscountPolicy` and its focused test.

## 4. Order validation

Files: src/main/java/com/example/validation/OrderValidator.java, src/test/java/com/example/validation/OrderValidatorTest.java
Depends on: none

- [ ] 4.1 Add positive-item `OrderValidator` behavior and its focused test.

## 5. Checkout integration

Files: src/main/java/com/example/checkout/CheckoutSummary.java, src/test/java/com/example/checkout/CheckoutSummaryTest.java
Depends on: 1, 2, 3, 4

- [ ] 5.1 Integrate all four policies in `CheckoutSummary` and prove the valid checkout scenario.

## 6. Shared registry hotspot

Files: src/main/java/com/example/checkout/CheckoutRegistry.java, src/test/java/com/example/checkout/CheckoutRegistryTest.java
Depends on: none

- [ ] 6.1 Register the stable checkout capability name and test it.
