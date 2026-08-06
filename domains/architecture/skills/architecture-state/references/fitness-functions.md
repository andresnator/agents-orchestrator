# Fitness Function Catalog

Automated checks that protect an architectural property in CI. Propose the smallest set that guards the decided boundaries; every proposal names its verify command so it can become a task with validation evidence.

## Java

**ArchUnit** (JUnit dependency `com.tngtech.archunit:archunit-junit5`):

```java
@AnalyzeClasses(packages = "com.acme")
class ArchitectureTest {
    @ArchTest
    static final ArchRule noCycles =
        slices().matching("com.acme.(*)..").should().beFreeOfCycles();

    @ArchTest
    static final ArchRule allowedDeps =
        layeredArchitecture().consideringAllDependencies()
            .layer("api").definedBy("..api..")
            .layer("domain").definedBy("..domain..")
            .layer("infra").definedBy("..infra..")
            .whereLayer("api").mayNotBeAccessedByAnyLayer()
            .whereLayer("domain").mayOnlyBeAccessedByLayers("api", "infra");
}
```

Verify: `mvn test` / `./gradlew test` (rules run as unit tests).

**Spring Modulith** (Spring Boot modular monoliths, `spring-modulith-starter-test`):

```java
ApplicationModules.of(Application.class).verify();
```

Verifies module boundaries and no-cycles from package structure; `Documenter` can also emit module diagrams. Verify: `mvn test`.

## JavaScript / TypeScript

**dependency-cruiser** (`.dependency-cruiser.cjs`):

```js
module.exports = {
  forbidden: [
    { name: "no-cycles", severity: "error", from: {}, to: { circular: true } },
    { name: "domain-stays-pure", severity: "error",
      from: { path: "^src/domain" }, to: { path: "^src/(api|infra)" } },
  ],
};
```

Verify: `npx depcruise src --config .dependency-cruiser.cjs` (wire into CI or a test script).

## Python

**import-linter** (`pyproject.toml` or `.importlinter`):

```ini
[importlinter]
root_package = acme

[importlinter:contract:layers]
name = Layered architecture
type = layers
layers =
    acme.api
    acme.domain
    acme.infra
```

Also supports `independence` (module isolation) and `forbidden` contracts. Verify: `lint-imports`.

## Proposal order

1. `no cycles between modules` — cheapest, catches the most rot.
2. `allowed dependencies only` (layers/allowlist) — encodes the decided boundaries.
3. Isolation contracts for extracted bounded contexts (modular monolith migrations).
4. Size/complexity metrics only when a concrete gap justifies them; do not propose speculative metric gates.
