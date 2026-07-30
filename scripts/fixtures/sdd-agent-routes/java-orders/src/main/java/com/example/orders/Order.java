package com.example.orders;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Objects;

/** A customer order: a reference plus the lines it carries. */
public final class Order {

    private final String reference;
    private final List<OrderLine> lines;

    public Order(String reference, List<OrderLine> lines) {
        this.reference = Objects.requireNonNull(reference, "reference");
        this.lines = new ArrayList<>(Objects.requireNonNull(lines, "lines"));
    }

    public String reference() {
        return reference;
    }

    public List<OrderLine> lines() {
        return Collections.unmodifiableList(lines);
    }

    public BigDecimal subtotal() {
        return lines.stream()
                .map(OrderLine::lineTotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
