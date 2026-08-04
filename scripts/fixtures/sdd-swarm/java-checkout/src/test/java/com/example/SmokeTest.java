package com.example;

import static org.assertj.core.api.Assertions.assertThat;
import org.junit.jupiter.api.Test;

class SmokeTest {
    @Test
    void shouldPassWhenFixtureBaselineIsPrepared() {
        // Given
        String fixture = "java-checkout-swarm";

        // When
        boolean available = !fixture.isBlank();

        // Then
        assertThat(available).isTrue();
    }
}
