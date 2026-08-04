import { execFileSync } from "node:child_process"
import fs from "node:fs"
import path from "node:path"

const group = process.argv[2]
const attempt = process.argv[3]
const scenario = process.env.SDD_SWARM_MOCK_SCENARIO ?? "success"
const javaTemp = process.env.MAVEN_OPTS?.match(/(?:^|\s)-Djava\.io\.tmpdir=([^\s]+)/)?.[1]

if (!javaTemp || !fs.existsSync(javaTemp) || !fs.statSync(javaTemp).isDirectory()) {
  throw new Error("controller must create java.io.tmpdir before launching a worker")
}

if (scenario === "timeout" && group === "1") await new Promise((resolve) => setTimeout(resolve, 10_000))
if (scenario === "retry-once" && group === "1" && attempt === "1") {
  fs.writeFileSync("STALE_TECHNICAL_RETRY.txt", "must not survive the fresh retry\n")
  process.exit(75)
}

const implementations = {
  "1": {
    main: "src/main/java/com/example/pricing/TaxCalculator.java",
    test: "src/test/java/com/example/pricing/TaxCalculatorTest.java",
    mainSource: `package com.example.pricing;

public final class TaxCalculator {
    private static final int TAX_PERCENT = 20;

    public int totalWithTax(int subtotal) {
        return subtotal + (subtotal * TAX_PERCENT / 100);
    }
}
`,
    testSource: `package com.example.pricing;

import static org.assertj.core.api.Assertions.assertThat;
import org.junit.jupiter.api.Test;

class TaxCalculatorTest {
    @Test
    void shouldAddTwentyPercentTaxWhenSubtotalIsPositive() {
        // Given
        TaxCalculator calculator = new TaxCalculator();

        // When
        int total = calculator.totalWithTax(100);

        // Then
        assertThat(total).isEqualTo(120);
    }
}
`,
  },
  "2": {
    main: "src/main/java/com/example/shipping/ShippingCalculator.java",
    test: "src/test/java/com/example/shipping/ShippingCalculatorTest.java",
    mainSource: `package com.example.shipping;

public final class ShippingCalculator {
    private static final int BASE_FEE = 5;

    public int feeFor(int items) {
        return items == 0 ? 0 : BASE_FEE + items;
    }
}
`,
    testSource: `package com.example.shipping;

import static org.assertj.core.api.Assertions.assertThat;
import org.junit.jupiter.api.Test;

class ShippingCalculatorTest {
    @Test
    void shouldIncludeBaseFeeWhenOrderHasItems() {
        // Given
        ShippingCalculator calculator = new ShippingCalculator();

        // When
        int fee = calculator.feeFor(2);

        // Then
        assertThat(fee).isEqualTo(7);
    }
}
`,
  },
  "3": {
    main: "src/main/java/com/example/discount/DiscountPolicy.java",
    test: "src/test/java/com/example/discount/DiscountPolicyTest.java",
    mainSource: `package com.example.discount;

public final class DiscountPolicy {
    private static final int DISCOUNT_THRESHOLD = 100;
    private static final int DISCOUNT_AMOUNT = 10;

    public int apply(int total) {
        return total >= DISCOUNT_THRESHOLD ? total - DISCOUNT_AMOUNT : total;
    }
}
`,
    testSource: `package com.example.discount;

import static org.assertj.core.api.Assertions.assertThat;
import org.junit.jupiter.api.Test;

class DiscountPolicyTest {
    @Test
    void shouldSubtractDiscountWhenThresholdIsReached() {
        // Given
        DiscountPolicy policy = new DiscountPolicy();

        // When
        int discounted = policy.apply(120);

        // Then
        assertThat(discounted).isEqualTo(110);
    }
}
`,
  },
  "4": {
    main: "src/main/java/com/example/validation/OrderValidator.java",
    test: "src/test/java/com/example/validation/OrderValidatorTest.java",
    mainSource: `package com.example.validation;

public final class OrderValidator {
    public boolean isValid(int items) {
        return items > 0;
    }
}
`,
    testSource: `package com.example.validation;

import static org.assertj.core.api.Assertions.assertThat;
import org.junit.jupiter.api.Test;

class OrderValidatorTest {
    @Test
    void shouldRejectOrderWhenItHasNoItems() {
        // Given
        OrderValidator validator = new OrderValidator();

        // When
        boolean valid = validator.isValid(0);

        // Then
        assertThat(valid).isFalse();
    }
}
`,
  },
  "5": {
    main: "src/main/java/com/example/checkout/CheckoutSummary.java",
    test: "src/test/java/com/example/checkout/CheckoutSummaryTest.java",
    mainSource: `package com.example.checkout;

import com.example.discount.DiscountPolicy;
import com.example.pricing.TaxCalculator;
import com.example.shipping.ShippingCalculator;
import com.example.validation.OrderValidator;

public final class CheckoutSummary {
    private final TaxCalculator taxCalculator = new TaxCalculator();
    private final ShippingCalculator shippingCalculator = new ShippingCalculator();
    private final DiscountPolicy discountPolicy = new DiscountPolicy();
    private final OrderValidator orderValidator = new OrderValidator();

    public int total(int subtotal, int items) {
        if (!orderValidator.isValid(items)) {
            throw new IllegalArgumentException("items must be positive");
        }
        return discountPolicy.apply(taxCalculator.totalWithTax(subtotal)) + shippingCalculator.feeFor(items);
    }
}
`,
    testSource: `package com.example.checkout;

import static org.assertj.core.api.Assertions.assertThat;
import org.junit.jupiter.api.Test;

class CheckoutSummaryTest {
    @Test
    void shouldCombinePricingDiscountAndShippingWhenOrderIsValid() {
        // Given
        CheckoutSummary summary = new CheckoutSummary();

        // When
        int total = summary.total(100, 2);

        // Then
        assertThat(total).isEqualTo(117);
    }
}
`,
  },
  "6": {
    main: "src/main/java/com/example/checkout/CheckoutRegistry.java",
    test: "src/test/java/com/example/checkout/CheckoutRegistryTest.java",
    mainSource: `package com.example.checkout;

public final class CheckoutRegistry {
    public String capabilityName() {
        return "parallel-checkout";
    }
}
`,
    testSource: `package com.example.checkout;

import static org.assertj.core.api.Assertions.assertThat;
import org.junit.jupiter.api.Test;

class CheckoutRegistryTest {
    @Test
    void shouldExposeStableNameWhenRegistryIsQueried() {
        // Given
        CheckoutRegistry registry = new CheckoutRegistry();

        // When
        String name = registry.capabilityName();

        // Then
        assertThat(name).isEqualTo("parallel-checkout");
    }
}
`,
  },
}

const implementation = implementations[group]
if (!implementation) throw new Error(`unknown mock group: ${group}`)

for (const [file, source] of [[implementation.main, implementation.mainSource], [implementation.test, implementation.testSource]]) {
  fs.mkdirSync(path.dirname(file), { recursive: true })
  fs.writeFileSync(file, source)
}

const files = [implementation.main, implementation.test]
if (scenario === "out-of-scope" && group === "1") {
  fs.writeFileSync("OUTSIDE_SCOPE.md", "malicious fixture change\n")
  files.push("OUTSIDE_SCOPE.md")
}
execFileSync("git", ["add", "--", ...files], { stdio: "inherit" })
execFileSync("git", ["-c", "commit.gpgSign=false", "commit", "-m", `feat: implement swarm group ${group}`], { stdio: "inherit" })

if (scenario === "missing-receipt" && group === "1") process.exit(0)

const commit = execFileSync("git", ["rev-parse", "HEAD"], { encoding: "utf8" }).trim()
const changed = execFileSync("git", ["diff", "--name-only", "HEAD^..HEAD"], { encoding: "utf8" })
  .trim().split("\n").filter(Boolean).sort()

console.log(`wave: "${group}"
tasks_done: ["${group}.1"]
assertions:
  - "${group}.1 -> ${implementation.main}:1"
files_changed: ${JSON.stringify(changed)}
out_of_scope: ${scenario === "out-of-scope" && group === "1" ? "[\"OUTSIDE_SCOPE.md\"]" : "[]"}
validation: "pass"
commit: "${commit}"
blockers: []`)
