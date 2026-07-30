package com.example.orders;

import java.math.BigDecimal;
import java.util.Objects;

/** One priced line inside an order. */
public final class OrderLine {

    private final String sku;
    private final int quantity;
    private final BigDecimal unitPrice;

    public OrderLine(String sku, int quantity, BigDecimal unitPrice) {
        this.sku = Objects.requireNonNull(sku, "sku");
        this.quantity = quantity;
        this.unitPrice = Objects.requireNonNull(unitPrice, "unitPrice");
    }

    public String sku() {
        return sku;
    }

    public int quantity() {
        return quantity;
    }

    public BigDecimal unitPrice() {
        return unitPrice;
    }

    public BigDecimal lineTotal() {
        return unitPrice.multiply(BigDecimal.valueOf(quantity));
    }
}
