package com.example.orders;

import java.math.BigDecimal;
import java.math.RoundingMode;

/** Applies the pricing rules an order goes through before checkout. */
public final class OrderPricing {

    private static final BigDecimal BULK_THRESHOLD = new BigDecimal("100.00");
    private static final BigDecimal BULK_RATE = new BigDecimal("0.05");
    private static final int MONEY_SCALE = 2;

    public BigDecimal total(Order order) {
        BigDecimal subtotal = order.subtotal();
        return subtotal.subtract(bulkDiscount(subtotal)).setScale(MONEY_SCALE, RoundingMode.HALF_UP);
    }

    public BigDecimal bulkDiscount(BigDecimal subtotal) {
        if (subtotal.compareTo(BULK_THRESHOLD) < 0) {
            return BigDecimal.ZERO;
        }
        return subtotal.multiply(BULK_RATE);
    }

    /**
     * Splits a discount evenly across the lines of an order so each line can be
     * reported with its own share.
     */
    public BigDecimal discountPerLine(Order order, BigDecimal discount) {
        return discount.divide(BigDecimal.valueOf(order.lines().size()), MONEY_SCALE, RoundingMode.HALF_UP);
    }
}
