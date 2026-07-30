package com.example.orders;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.math.BigDecimal;
import java.util.List;
import org.junit.jupiter.api.Test;

class OrderPricingTest {

    private static final String REFERENCE = "ORD-1";
    private static final String SKU = "SKU-1";

    private final OrderPricing pricing = new OrderPricing();

    @Test
    void totalsAnOrderBelowTheBulkThresholdWithoutDiscount() {
        Order order = orderOf(new OrderLine(SKU, 2, new BigDecimal("10.00")));

        assertEquals(new BigDecimal("20.00"), pricing.total(order));
    }

    @Test
    void appliesTheBulkDiscountFromTheThresholdOnwards() {
        Order order = orderOf(new OrderLine(SKU, 10, new BigDecimal("20.00")));

        assertEquals(new BigDecimal("190.00"), pricing.total(order));
    }

    @Test
    void sumsEveryLineIntoTheSubtotal() {
        Order order = orderOf(
                new OrderLine(SKU, 1, new BigDecimal("5.50")),
                new OrderLine("SKU-2", 3, new BigDecimal("2.00")));

        assertEquals(new BigDecimal("11.50"), order.subtotal());
    }

    private static Order orderOf(OrderLine... lines) {
        return new Order(REFERENCE, List.of(lines));
    }
}
