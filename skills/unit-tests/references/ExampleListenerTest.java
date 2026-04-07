package com.example.app.listener;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.stream.Stream;

import org.assertj.core.api.WithAssertions;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class ExampleListenerTest implements WithAssertions {

    private static final String MOCK_MESSAGE = "{}";

    @Mock
    private MessageProcessor messageProcessor;

    @Mock
    private MessageParser messageParser;

    @InjectMocks
    private ExampleListener exampleListener;

    @BeforeEach
    void setUp() {
        System.setProperty("lvslogger.enableConsoleLogger", "false");
    }

    static Stream<Arguments> messageTypesProvider() {
        return Stream.of(
                Arguments.of("defaultQueue", "feed_defaultQueue", MessageType.DEFAULT),
                Arguments.of("systemQueue", "feed_systemQueue", MessageType.SYSTEM),
                Arguments.of("resultingQueue", "feed_resultingQueue", MessageType.RESULTING)
        );
    }

    @ParameterizedTest
    @MethodSource("messageTypesProvider")
    void shouldProcessMessageCorrectlyWhenReceived(String queueName, String expectedLogName, MessageType expectedType) {
        // Given
        ParsedMessage parsedMessage = new ParsedMessage(expectedType, "content");
        when(messageParser.parse(MOCK_MESSAGE)).thenReturn(parsedMessage);

        // When
        exampleListener.onMessage(MOCK_MESSAGE, queueName);

        // Then
        ArgumentCaptor<ProcessedMessage> captor = ArgumentCaptor.forClass(ProcessedMessage.class);
        verify(messageProcessor).process(captor.capture());
        assertThat(captor.getValue().getType()).isEqualTo(expectedType);
        assertThat(captor.getValue().getSource()).isEqualTo(expectedLogName);
    }

    static Stream<Arguments> validationScenarios() {
        return Stream.of(
                Arguments.of("valid message", true, 0),
                Arguments.of("invalid message", false, 1),
                Arguments.of("", false, 2),
                Arguments.of(null, false, 3)
        );
    }

    @ParameterizedTest
    @MethodSource("validationScenarios")
    void shouldValidateMessageCorrectly(String message, boolean isValid, int expectedErrorCode) {
        // Given
        when(messageParser.isValid(message)).thenReturn(isValid);

        // When
        ValidationResult result = exampleListener.validate(message);

        // Then
        assertThat(result.isValid()).isEqualTo(isValid);
        if (!isValid) {
            assertThat(result.getErrorCode()).isEqualTo(expectedErrorCode);
        }
    }

    enum MessageType {
        DEFAULT, SYSTEM, RESULTING
    }

    static class ParsedMessage {
        private final MessageType type;
        private final String content;

        ParsedMessage(MessageType type, String content) {
            this.type = type;
            this.content = content;
        }

        MessageType getType() { return type; }
        String getContent() { return content; }
    }

    static class ProcessedMessage {
        private MessageType type;
        private String source;

        MessageType getType() { return type; }
        String getSource() { return source; }
    }

    static class ValidationResult {
        private boolean valid;
        private int errorCode;

        boolean isValid() { return valid; }
        int getErrorCode() { return errorCode; }
    }

    interface MessageProcessor {
        void process(ProcessedMessage message);
    }

    interface MessageParser {
        ParsedMessage parse(String message);
        boolean isValid(String message);
    }

    static class ExampleListener {
        private final MessageProcessor processor;
        private final MessageParser parser;

        ExampleListener(MessageProcessor processor, MessageParser parser) {
            this.processor = processor;
            this.parser = parser;
        }

        void onMessage(String message, String queueName) {
        }

        ValidationResult validate(String message) {
            return null;
        }
    }
}
