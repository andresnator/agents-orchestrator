package com.example.app.config;

import static org.assertj.core.api.Assertions.tuple;

import java.math.BigDecimal;
import java.util.List;

import org.assertj.core.api.WithAssertions;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.InjectMocks;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

@ExtendWith(MockitoExtension.class)
class ExampleConfigTest implements WithAssertions {

    @InjectMocks
    private ExampleConfig exampleConfig;

    @Test
    void shouldReturnCorrectDTOsWhenValidConfig() {
        // Given
        ReflectionTestUtils.setField(exampleConfig, "configProperty", "key1:value1:10,key2:value2:20");

        // When
        List<ExampleConfigDTO> result = exampleConfig.parseConfiguration();

        // Then
        assertThat(result)
                .isNotNull()
                .hasSize(2)
                .extracting("key", "value", "number")
                .containsExactly(
                        tuple("key1", "value1", 10),
                        tuple("key2", "value2", 20)
                );
    }

    @ParameterizedTest
    @ValueSource(strings = { "invalid", "key1:value1", "key1:value1:notanumber" })
    void shouldReturnEmptyListWhenInvalidConfig(String invalidConfig) {
        // Given
        ReflectionTestUtils.setField(exampleConfig, "configProperty", invalidConfig);

        // When
        List<ExampleConfigDTO> result = exampleConfig.parseConfiguration();

        // Then
        assertThat(result)
                .isNotNull()
                .isEmpty();
    }

    @ParameterizedTest
    @NullAndEmptySource
    void shouldReturnEmptyListWhenConfigIsNullOrEmpty(String config) {
        // Given
        ReflectionTestUtils.setField(exampleConfig, "configProperty", config);

        // When
        List<ExampleConfigDTO> result = exampleConfig.parseConfiguration();

        // Then
        assertThat(result)
                .isNotNull()
                .isEmpty();
    }

    @Test
    void shouldParseDecimalValuesCorrectly() {
        // Given
        ReflectionTestUtils.setField(exampleConfig, "decimalProperty", "0.15,0.25,0.35");

        // When
        List<BigDecimal> result = exampleConfig.parseDecimals();

        // Then
        assertThat(result)
                .hasSize(3)
                .containsExactly(
                        new BigDecimal("0.15"),
                        new BigDecimal("0.25"),
                        new BigDecimal("0.35")
                );
    }

    static class ExampleConfig {
        private String configProperty;
        private String decimalProperty;

        List<ExampleConfigDTO> parseConfiguration() {
            return List.of();
        }

        List<BigDecimal> parseDecimals() {
            return List.of();
        }
    }

    static class ExampleConfigDTO {
        private String key;
        private String value;
        private int number;
    }
}
