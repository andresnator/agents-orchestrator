---
name: unit-tests
description: |
  Generates idiomatic unit tests in any language. Detects the project's language and test framework
  automatically. Works with Java, Python, TypeScript, JavaScript, C#, Go, Kotlin, Ruby, PHP, Rust, Swift.
  Use this skill whenever the user needs unit tests — even if they just say "add tests" or "cover this
  class" without specifying a framework. Triggers: "unit test", "write tests", "add tests", "test
  coverage", "mock", "stub", "spy", "test this", "cover this", or any testing-related request.
  Also triggers on: "test unitario", "crear tests", "añadir tests", "prueba unitaria", "testear",
  "mockear", "cobertura", "cubrir con tests", "generar tests".
  For Java-specific JUnit 5 + Mockito + AssertJ patterns with compiled reference examples, use unit-tests-java.
license: MIT
metadata:
  author: andresnator
  version: "2.0"
---

# Adding Unit Tests (Multi-Language)

Use this skill when the user requests the creation or update of unit tests in **any** project. Detects the language and test framework automatically to generate idiomatic tests.

## Step 0: Detect Language and Test Ecosystem

Before generating any test, detect the project's stack:

| Language | Test Framework | Mocking Tool | Assertion Style | Test Location |
|----------|---------------|--------------|-----------------|---------------|
| **Java** | JUnit 5 | Mockito | AssertJ `assertThat()` | `src/test/java/` mirroring packages |
| **Python** | pytest | unittest.mock / pytest-mock | `assert` (plain) or pytest assertions | `tests/` mirroring source, or `test_*.py` alongside |
| **TypeScript** | Jest / Vitest | jest.mock / vi.mock / jest.spyOn | `expect().toBe()` / `expect().toEqual()` | `__tests__/` or `*.test.ts` / `*.spec.ts` alongside |
| **JavaScript** | Jest / Vitest / Mocha | jest.mock / sinon | `expect()` | `__tests__/` or `*.test.js` / `*.spec.js` alongside |
| **C#** | xUnit / NUnit | Moq / NSubstitute | `Assert.Equal()` / FluentAssertions `Should()` | `*.Tests` project mirroring namespace |
| **Go** | testing (stdlib) | testify/mock / gomock / interfaces | `assert.Equal()` (testify) or `if got != want` | `*_test.go` same package |
| **Kotlin** | JUnit 5 / Kotest | MockK | Kotest matchers or AssertJ | `src/test/kotlin/` mirroring packages |
| **Ruby** | RSpec / Minitest | rspec-mocks / mocha | `expect().to eq()` / `assert_equal` | `spec/` or `test/` mirroring source |
| **PHP** | PHPUnit / Pest | Mockery / PHPUnit mocks | `$this->assertEquals()` / `assertThat()` | `tests/` mirroring namespace |
| **Rust** | `#[test]` (stdlib) | mockall (traits) | `assert_eq!` / `assert!` | `#[cfg(test)] mod tests` in same file, or `tests/` |
| **Swift** | XCTest / Quick+Nimble | Protocol-based mocking | `XCTAssertEqual()` / `expect().to(equal())` | `*Tests/` target |

**Detection heuristic**: Check project files — `pom.xml`/`build.gradle` → Java, `package.json` → TS/JS, `pyproject.toml`/`requirements.txt`/`setup.py` → Python, `*.csproj` → C#, `go.mod` → Go, `Cargo.toml` → Rust, `Gemfile` → Ruby, `composer.json` → PHP, `Package.swift` → Swift, `build.gradle.kts` → Kotlin.

If the language is **Java** and the user needs detailed JUnit 5 / Mockito / AssertJ reference examples, delegate to the `unit-tests-java` skill.

## Instructions

Follow these steps to generate unit tests in **any** language:

1. **Detect** the language and test framework (Step 0)
2. **Naming Convention**: Use the language's idiomatic test naming (see [Naming Conventions by Language](#naming-conventions-by-language))
3. **Structure**: Follow the Arrange/Act/Assert (AAA) pattern — expressed idiomatically per language
4. **Minimal comments**: Only use `// Arrange`, `// Act`, `// Assert` (or language equivalent) section markers. No other comments or docstrings unless absolutely necessary.
5. **Select Pattern**: Choose the appropriate testing pattern below based on the verification need
6. **Mocking**: Use the language's standard mocking tool (see Step 0 table). Prefer constructor/parameter injection over monkey-patching.

## Naming Conventions by Language

| Language | Test File | Test Class/Suite | Test Method/Function |
|----------|-----------|-----------------|---------------------|
| **Java** | `{ClassName}Test.java` | `{ClassName}Test` | `should{Behavior}When{Condition}` |
| **Python** | `test_{module}.py` | `Test{ClassName}` (or no class with pytest) | `test_should_{behavior}_when_{condition}` |
| **TypeScript/JS** | `{module}.test.ts` or `{module}.spec.ts` | `describe('{ClassName}')` | `it('should {behavior} when {condition}')` |
| **C#** | `{ClassName}Tests.cs` | `{ClassName}Tests` | `Should{Behavior}_When{Condition}` |
| **Go** | `{file}_test.go` | (none — package-level) | `Test{Function}_{Condition}` |
| **Kotlin** | `{ClassName}Test.kt` | `{ClassName}Test` | `` `should {behavior} when {condition}` `` (backtick) or camelCase |
| **Ruby** | `{class}_spec.rb` (RSpec) | `RSpec.describe {ClassName}` | `it '{behavior} when {condition}'` |
| **PHP** | `{ClassName}Test.php` | `{ClassName}Test` | `test_{behavior}_when_{condition}` or `testShouldBehaviorWhenCondition` |
| **Rust** | same file (`mod tests`) or `tests/{name}.rs` | `mod tests` | `fn test_{behavior}_when_{condition}()` |
| **Swift** | `{ClassName}Tests.swift` | `{ClassName}Tests: XCTestCase` | `test_{behavior}_when_{condition}()` |

## Patterns

### Pattern 1: Basic Mock Test

Test a unit with mocked dependencies.

**Java** (JUnit 5 + Mockito + AssertJ):
```java
@ExtendWith(MockitoExtension.class)
class OrderServiceTest implements WithAssertions {
    @Mock private OrderRepository repository;
    @InjectMocks private OrderService service;

    @Test
    void shouldReturnOrderWhenIdExists() {
        // Arrange
        when(repository.findById(1L)).thenReturn(Optional.of(order));
        // Act
        var result = service.getOrder(1L);
        // Assert
        assertThat(result).isEqualTo(order);
    }
}
```

**Python** (pytest + unittest.mock):
```python
from unittest.mock import Mock

def test_should_return_order_when_id_exists():
    # Arrange
    repository = Mock()
    repository.find_by_id.return_value = order
    service = OrderService(repository)
    # Act
    result = service.get_order(1)
    # Assert
    assert result == order
```

**TypeScript** (Jest):
```typescript
describe('OrderService', () => {
  it('should return order when id exists', () => {
    // Arrange
    const repository = { findById: jest.fn().mockReturnValue(order) };
    const service = new OrderService(repository);
    // Act
    const result = service.getOrder(1);
    // Assert
    expect(result).toEqual(order);
  });
});
```

**C#** (xUnit + Moq):
```csharp
public class OrderServiceTests {
    [Fact]
    public void ShouldReturnOrder_WhenIdExists() {
        // Arrange
        var repository = new Mock<IOrderRepository>();
        repository.Setup(r => r.FindById(1)).Returns(order);
        var service = new OrderService(repository.Object);
        // Act
        var result = service.GetOrder(1);
        // Assert
        Assert.Equal(order, result);
    }
}
```

**Go** (testing + testify):
```go
func TestGetOrder_WhenIdExists(t *testing.T) {
	// Arrange
	repo := new(MockOrderRepository)
	repo.On("FindById", 1).Return(order, nil)
	service := NewOrderService(repo)
	// Act
	result, err := service.GetOrder(1)
	// Assert
	assert.NoError(t, err)
	assert.Equal(t, order, result)
}
```

**Rust** (mockall):
```rust
#[cfg(test)]
mod tests {
    use super::*;
    use mockall::predicate::*;

    #[test]
    fn test_get_order_when_id_exists() {
        // Arrange
        let mut repo = MockOrderRepository::new();
        repo.expect_find_by_id().with(eq(1)).returning(|_| Ok(order));
        let service = OrderService::new(Box::new(repo));
        // Act
        let result = service.get_order(1).unwrap();
        // Assert
        assert_eq!(result, order);
    }
}
```

### Pattern 2: Parameterized / Table-Driven Tests

Test multiple data variations with a single test structure.

**Java** (JUnit 5):
```java
@ParameterizedTest
@MethodSource("invalidInputs")
void shouldRejectWhenInputInvalid(String input, String expectedError) {
    assertThatThrownBy(() -> service.validate(input))
        .hasMessage(expectedError);
}

static Stream<Arguments> invalidInputs() {
    return Stream.of(
        Arguments.of("", "must not be empty"),
        Arguments.of(null, "must not be null")
    );
}
```

**Python** (pytest.mark.parametrize):
```python
@pytest.mark.parametrize("input_val, expected_error", [
    ("", "must not be empty"),
    (None, "must not be null"),
])
def test_should_reject_when_input_invalid(input_val, expected_error):
    with pytest.raises(ValueError, match=expected_error):
        service.validate(input_val)
```

**TypeScript** (Jest each):
```typescript
it.each([
  ['', 'must not be empty'],
  [null, 'must not be null'],
])('should reject when input is %s', (input, expectedError) => {
  expect(() => service.validate(input)).toThrow(expectedError);
});
```

**Go** (table-driven):
```go
func TestValidate_InvalidInputs(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{"empty", "", "must not be empty"},
		{"whitespace", "  ", "must not be blank"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := service.Validate(tt.input)
			assert.EqualError(t, err, tt.want)
		})
	}
}
```

**Rust** (macro or loop):
```rust
#[test]
fn test_validate_invalid_inputs() {
    let cases = vec![
        ("", "must not be empty"),
        ("  ", "must not be blank"),
    ];
    for (input, expected) in cases {
        let err = service.validate(input).unwrap_err();
        assert_eq!(err.to_string(), expected);
    }
}
```

### Pattern 3: Exception / Error Testing

Verify that errors are thrown/returned correctly. Each language has its own idiom:

| Language | Exception/Error assertion |
|----------|-------------------------|
| **Java** | `assertThatThrownBy(() -> svc.process(null)).isInstanceOf(IllegalArgumentException.class).hasMessage("input required")` |
| **Python** | `with pytest.raises(ValueError, match="input required"): svc.process(None)` |
| **TypeScript** | `expect(() => svc.process(null)).toThrow('input required')` — async: `await expect(svc.processAsync(null)).rejects.toThrow(...)` |
| **C#** | `Assert.Throws<ArgumentException>(() => svc.Process(null))` |
| **Go** | `_, err := svc.Process(""); assert.EqualError(t, err, "input required")` |
| **Rust** | `let err = svc.process("").unwrap_err(); assert_eq!(err.to_string(), "input required")` |

### Pattern 4: Spy / Verify Interactions

Verify that a dependency was called with specific arguments.

| Language | Verification idiom |
|----------|--------------------|
| **Java** | `ArgumentCaptor<Event> c = ArgumentCaptor.forClass(Event.class); verify(pub).publish(c.capture()); assertThat(c.getValue().getType()).isEqualTo("ORDER_CREATED")` |
| **Python** | `pub.publish.assert_called_once(); event = pub.publish.call_args[0][0]; assert event.type == "ORDER_CREATED"` |
| **TypeScript** | `expect(pub.publish).toHaveBeenCalledWith(expect.objectContaining({ type: 'ORDER_CREATED' }))` |
| **Go** | `repo.AssertCalled(t, "Save", mock.MatchedBy(func(o Order) bool { return o.Status == "CREATED" }))` |

### Pattern 5: Async Test

Test asynchronous code — only applies to languages with async support.

**TypeScript** (Jest):
```typescript
it('should fetch data', async () => {
  api.get.mockResolvedValue({ data: expected });
  const result = await service.fetchData();
  expect(result).toEqual(expected);
});
```

**Python** (pytest-asyncio):
```python
@pytest.mark.asyncio
async def test_should_fetch_data():
    api.get = AsyncMock(return_value=expected)
    result = await service.fetch_data()
    assert result == expected
```

**Rust** (tokio::test):
```rust
#[tokio::test]
async fn test_fetch_data() {
    let mut api = MockApi::new();
    api.expect_get().returning(|_| Ok(expected));
    let service = Service::new(Box::new(api));
    let result = service.fetch_data().await.unwrap();
    assert_eq!(result, expected);
}
```

## Checklist

- [ ] Detected language and test framework correctly
- [ ] Test file location follows project convention
- [ ] Test naming follows language idiom (see naming table)
- [ ] Arrange/Act/Assert structure is clear
- [ ] Only section-marker comments — no unnecessary docs
- [ ] Mocking uses the standard tool for the language
- [ ] Verify calls only when interaction matters (not on every mock)
- [ ] Assertions are idiomatic for the framework
- [ ] Test is complete and runnable (all imports/requires included)

## Reference Examples

For Java-specific compiled reference examples (JUnit 5 + Mockito + AssertJ), see the `unit-tests-java` skill which includes:
- `ExampleServiceTest.java` - Basic Mockito tests with @Mock and @InjectMocks
- `ExampleConfigTest.java` - Configuration class testing with property injection
- `ExampleHandlerTest.java` - Handler testing with ArgumentCaptor
- `ExampleListenerTest.java` - Event listener testing with complex mocking
- `ExampleCacheTest.java` - Cache testing with parameterized tests and edge cases

For all other languages, use the multi-language patterns documented above in this skill.
