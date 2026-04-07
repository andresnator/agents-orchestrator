---
name: unit-tests
description: |
  Generates JUnit 5 and Mockito unit tests following project conventions like naming, structure, and assertion styles. Use when the user requests (1) Creating new unit tests, (2) Testing services/components with mocks, (3) Adding test coverage, (4) Writing parameterized tests, (5) Testing exceptions or edge cases. Triggers include mentions of "unit test", "test", "JUnit", "Mockito", "test coverage", "@Test", or testing-related tasks in any Java project.
  También se activa en castellano: "test unitario", "tests unitarios", "crear tests",
  "añadir tests", "prueba unitaria", "pruebas unitarias", "escribir un test",
  "hacer tests", "testear esta clase", "test con Mockito", "mockear dependencias",
  "cobertura de tests", "no tiene tests", "añadir cobertura", "crear pruebas",
  "test parametrizado", "test de excepción", "testear el servicio",
  "cubrir con tests", "generar tests".
license: MIT
metadata:
  author: andresnator
  version: "1.0"
---

# Adding Unit Tests

Use this skill when the user requests the creation or update of unit tests in any Java project using JUnit 5 and Mockito.

## Instructions

Follow these steps to generate unit tests:

1. **Naming Convention**: Name the test class `{ClassName}Test`. Name methods `should{Behavior}When{Condition}` (camelCase).
2. **Structure**:
   - Location: `src/test/java/` mirroring the source package structure.
   - Use `// Given`, `// When`, `// Then` style comments in test methods.
   - **NO OTHER COMMENTS/JAVADOCS**: Do not add method-level or class-level Javadocs unless absolutely necessary.
3. **Dependencies**:
   - Use `JUnit 5` (`@Test`, `@ExtendWith(MockitoExtension.class)`).
   - Use `Mockito` for mocking (`@Mock`, `@InjectMocks`).
   - Use `AssertJ` for assertions (`assertThat()`).
   - Implement `WithAssertions` interface in the test class to avoid static imports for assertions.
4. **Select Pattern**: Choose the appropriate testing pattern below based on the verification needs (Basic, Exception, Parameterized, etc.).

## Patterns

### Pattern 1: Basic Mockito Test
Use for standard service testing.

```java
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.assertj.core.api.WithAssertions;

@ExtendWith(MockitoExtension.class)
class TargetClassTest implements WithAssertions {

    @Mock
    private DependencyClass dependency;

    @InjectMocks
    private TargetClass targetClass;

    @Test
    void shouldReturnResultWhenInputValid() {
        // Given
        when(dependency.call()).thenReturn(expected);

        // When
        var result = targetClass.execute();

        // Then
        assertThat(result).isEqualTo(expected);
        verify(dependency).call();
    }
}
```

### Pattern 2: Extending a Project Base Test Class
Use when the project has a shared base test class with common utilities (test fixtures, builders, constants).

```java
class TargetClassTest extends BaseTest implements WithAssertions {
    // Inherits common mocks, builders, and test utilities
}
```

### Pattern 3: ReflectionTestUtils
Use to inject private fields not exposed via constructor.

```java
ReflectionTestUtils.setField(targetClass, "fieldName", "value");
```

### Pattern 4: Parameterized Tests
Use for testing multiple data variations.

```java
@ParameterizedTest
@ValueSource(strings = { "", "invalid" })
void shouldFailWhenInputInvalid(String input) {
    // ...
}

@ParameterizedTest
@MethodSource("provider")
void shouldWorkWhenInputValid(String input, int expected) {
    // ...
}

static Stream<Arguments> provider() {
    return Stream.of(Arguments.of("a", 1));
}
```

### Pattern 5: ArgumentCaptor
Use to verify complex objects passed to mocks.

```java
ArgumentCaptor<Dto> captor = ArgumentCaptor.forClass(Dto.class);
verify(mock).method(captor.capture());
assertThat(captor.getValue().getField()).isEqualTo("expected");
```

### Pattern 6: Exception Testing
Use to verify thrown exceptions.

```java
assertThatThrownBy(() -> target.method())
    .isInstanceOf(IllegalArgumentException.class)
    .hasMessage("error");
```

## Common Imports

**Mockito**:
```java
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.never;
```

**JUnit 5**:
```java
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.junit.jupiter.MockitoExtension;
```

## Checklist

- [ ] Match package structure exactly
- [ ] Implement `WithAssertions` interface
- [ ] Use `should{Behavior}When{Condition}` naming
- [ ] Only `// Given`, `// When`, `// Then` comments allowed
- [ ] Verify mocks with `verify(mock)` only when necessary
- [ ] Use `assertThat()` for all assertions

## Reference Examples

For complete working test examples following all patterns above, see the `references/` directory:
- `ExampleServiceTest.java` - Basic Mockito tests with @Mock and @InjectMocks
- `ExampleConfigTest.java` - Configuration class testing with property injection
- `ExampleHandlerTest.java` - Handler testing with ArgumentCaptor
- `ExampleListenerTest.java` - Event listener testing with complex mocking
- `ExampleCacheTest.java` - Cache testing with parameterized tests and edge cases

These examples demonstrate idiomatic test implementations and should be consulted when writing similar tests.
