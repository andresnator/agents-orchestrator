import com.example.checkout.CheckoutRegistry;
import com.example.checkout.CheckoutSummary;

public final class GoldenVerifier {
    private GoldenVerifier() {
    }

    public static void main(String[] args) {
        CheckoutSummary summary = new CheckoutSummary();
        if (summary.total(100, 2) != 117) {
            throw new AssertionError("checkout total differs from the golden result");
        }
        try {
            summary.total(100, 0);
            throw new AssertionError("empty checkout was accepted");
        } catch (IllegalArgumentException expected) {
            // Expected boundary behavior.
        }
        if (!"parallel-checkout".equals(new CheckoutRegistry().capabilityName())) {
            throw new AssertionError("registry name differs from the golden result");
        }
    }
}
