---
name: oc-refactor
description: |
  Cross-language catalog of 62+ refactoring techniques based on Martin Fowler's "Refactoring" and
  Alexander Shvets' "Refactoring Guru". Detects the project's language automatically and provides
  idiomatic examples. Works with Java, Python, TypeScript, JavaScript, C#, Go, Kotlin, Ruby, PHP,
  Rust, Swift. Use this skill whenever the user asks to refactor code, improve code quality, eliminate
  code smells, simplify conditionals, restructure classes, improve API design, or apply any named
  refactoring technique. Also trigger when the user mentions code smells, legacy code improvement,
  clean code practices, SOLID principles, or asks "how can I improve this code". Even if the user
  just pastes code and asks for improvement suggestions, use this skill to identify applicable techniques.
  También se activa en castellano: "refactorizar", "refactorizar código",
  "mejorar este código", "malos olores del código", "olores de código",
  "código sucio", "limpiar código", "simplificar condicionales", "principios SOLID",
  "cómo mejorar este código", "código limpio", "reestructurar clase",
  "mejorar calidad del código", "técnica de refactorización", "extraer método",
  "renombrar variable", "mover método", "eliminar código duplicado",
  "reducir complejidad", "mejorar legibilidad", "reorganizar código".
  Includes general Java detection; Java examples should follow the project's Java version and idioms.
license: MIT
metadata:
  author: andresnator
  status: done
  version: "2.1.0"
---

# Refactoring Catalog (Multi-Language)

## Intent

- **Goal:** Improve code structure with named refactoring techniques, applied idiomatically for the detected language, without altering observable behavior.
- **Limits:** Refactoring is a disciplined technique, not a random cleanup. Cover → Modify → Refactor: always have tests before you start. Small steps: test after each change and commit frequently; never batch multiple changes.
- **Fails if:** Observable behavior changes, a technique is applied where `references/language-applicability.md` says it does not apply, or a Java refactor ends without the Java completion gate verdict.

## Context

- **Reads:** Project files for language detection; `techniques/00-code-smells-diagnostic.md` (maps 24 code smells to techniques); the technique files under `techniques/`; files under `references/`.
- **Never reads:** Unrelated technique files once smells are diagnosed.
- **Persona:** Refactoring practitioner following Martin Fowler's *Refactoring* (2nd Edition) and Alexander Shvets' *Refactoring in Java* (Refactoring Guru), with idiomatic Python, TypeScript, Go, and Rust examples.
- **Scope:** Refactor requests, code quality, code smells, conditionals, class restructuring, API design, named techniques, legacy improvement, clean code, SOLID, or pasted code needing improvement, in any language in the description.

## Expectations

- **Scenarios:**
  - WHEN given code THEN detect the language, diagnose smells, read the matching technique file(s), check applicability (use the table's alternative if not applicable), and apply in small steps, testing between changes.
  - WHEN several techniques compete THEN use `references/selection-heuristics.md`.
  - WHEN the language is Java THEN apply Java OOP, Stream API where appropriate, the project's detected Java version (Java 8 versus Java 11+ API availability), and read `references/java-notes.md`.
- **Done means:** Idiomatic examples for the detected language, an explanation of WHY each refactoring improves the code (not just HOW), and for Java the `references/java-notes.md` Java completion gate verdict.
- **Quality needs:** Names matter more than length; intention over implementation; data and logic that change together live together; prefer composition over inheritance; immutability is a powerful preservative; CQS — a function either returns a value or modifies state, never both.

## Method

### Detect language

| Project File | Language | Idiom Style |
|---|---|---|
| `pom.xml` / `build.gradle` | Java | OOP, Stream API |
| `pyproject.toml` / `requirements.txt` / `setup.py` | Python | Duck typing, comprehensions |
| `package.json` + `tsconfig.json` | TypeScript | Functional-OOP hybrid |
| `package.json` (no tsconfig) | JavaScript | Prototype-based, functional |
| `*.csproj` | C# | OOP, LINQ |
| `go.mod` | Go | Composition, implicit interfaces |
| `build.gradle.kts` | Kotlin | OOP + functional |
| `Gemfile` | Ruby | Duck typing, open classes |
| `composer.json` | PHP | OOP |
| `Cargo.toml` | Rust | Ownership, traits, no inheritance |
| `Package.swift` | Swift | Protocol-oriented |

### Language support

| Concept | Python | TypeScript | Go | Rust |
|---|---|---|---|---|
| Class / struct | `class` | `class` | `struct` + methods | `struct` + `impl` |
| Inheritance | `class Child(Parent)` | `extends` | Embedding (no inheritance) | Traits (no inheritance) |
| Interface / contract | `Protocol` / `ABC` | `interface` | `interface` (implicit) | `trait` |
| Encapsulation | `_private` convention | `private` keyword | Unexported (lowercase) | Private by default, `pub` |
| Polymorphism | Duck typing + ABC | Interfaces + classes | Implicit interfaces | Trait objects + generics |
| Generics | `typing.Generic[T]` | `<T>` | `[T any]` | `<T: Trait>` |
| Error handling | Exceptions | Exceptions | Error values (`error`) | `Result<T, E>` |
| Null safety | `None` / `Optional[T]` | `null` / `undefined` / `?` | `nil` (zero values) | `Option<T>` |
| Collections pipeline | Comprehensions / generators | Array methods (`.map`, `.filter`) | `for range` (no pipeline) | Iterator chain (`.filter().map()`) |
| Pattern matching | `match` (3.10+) | `switch` (no pattern matching) | `switch` (no pattern matching) | `match` (exhaustive) |
| Factory pattern | `@classmethod` / module function | Static method / function | `NewXxx()` function | `Type::new()` associated fn |
| Builder pattern | `__init__` + kwargs / dataclass | Fluent builder class | Functional options | Builder with consuming `self` |

For detailed concept-to-language mappings, see `references/language-idioms.md`.

### Technique catalog

The techniques are organized in 7 groups. Each technique has its own file in the `techniques/` directory.

#### Group 1: Composing Methods (techniques/01-XX)
Techniques for building clean, well-structured methods. The foundation of all refactoring.
- `01-extract-method.md` — Extract a code fragment into a named function
- `02-inline-method.md` — Replace a function call with the function body
- `03-extract-variable.md` — Give a name to a complex expression
- `04-inline-variable.md` — Remove a variable that adds no clarity
- `05-replace-temp-with-query.md` — Replace temp variables with function calls
- `06-replace-method-with-method-object.md` — Turn a complex function into its own class/struct
- `07-substitute-algorithm.md` — Replace an algorithm with a clearer version

#### Group 2: Moving Features (techniques/02-XX)
Techniques for placing code where it truly belongs.
- `08-move-method.md` — Move a function to where it has more cohesion
- `09-move-field.md` — Move a field to the type that uses it most
- `10-extract-class.md` — Split a type with multiple responsibilities
- `11-inline-class.md` — Merge a type that does too little
- `12-hide-delegate.md` — Encapsulate chain navigation behind a simpler interface
- `13-remove-middle-man.md` — Remove unnecessary delegation
- `14-move-statements.md` — Move statements into/out of functions, slide statements
- `15-split-loop.md` — Separate a loop that does multiple things
- `16-replace-loop-with-pipeline.md` — Use declarative pipelines instead of imperative loops
- `17-remove-dead-code.md` — Delete unused code

#### Group 3: Organizing Data (techniques/03-XX)
Techniques for enriching data with behavior and protecting internal state.
- `18-encapsulate-variable.md` — Wrap data access with getters/functions
- `19-encapsulate-record.md` — Convert data structures into objects/structs
- `20-encapsulate-collection.md` — Protect collections from external mutation
- `21-replace-primitive-with-object.md` — Create domain types instead of using raw primitives
- `22-split-variable.md` — Give each purpose its own variable
- `23-rename-field.md` — Improve field names for clarity
- `24-replace-derived-variable-with-query.md` — Calculate values on demand
- `25-change-reference-to-value.md` — Make objects immutable (Value Objects)
- `26-change-value-to-reference.md` — Share a single instance across consumers
- `27-replace-type-code-with-subclasses.md` — Convert type codes to polymorphic hierarchy

#### Group 4: Simplifying Conditionals (techniques/04-XX)
Techniques for taming conditional complexity.
- `28-decompose-conditional.md` — Name condition and branches
- `29-consolidate-conditional.md` — Merge related conditions
- `30-replace-nested-conditional-with-guard-clauses.md` — Early returns for special cases
- `31-replace-conditional-with-polymorphism.md` — Use polymorphism instead of switch/if-type
- `32-introduce-special-case.md` — Null Object pattern for default behavior
- `33-introduce-assertion.md` — Document invariants with executable assertions
- `34-replace-control-flag.md` — Replace boolean flags with break/return

#### Group 5: Simplifying Method Calls / API Design (techniques/05-XX)
Techniques for building self-documenting interfaces.
- `35-change-function-declaration.md` — Rename functions and change parameters
- `36-introduce-parameter-object.md` — Group related parameters into an object
- `37-parameterize-function.md` — Unify similar functions with a parameter
- `38-remove-flag-argument.md` — Replace boolean params with named functions
- `39-preserve-whole-object.md` — Pass the object instead of extracted values
- `40-replace-parameter-with-query.md` — Let the function calculate what it needs
- `41-replace-query-with-parameter.md` — Pass value as param for purity/testability
- `42-remove-setting-method.md` — Make properties read-only
- `43-replace-constructor-with-factory.md` — Use factory functions for flexible creation
- `44-replace-function-with-command.md` — Encapsulate function as object
- `45-separate-query-from-modifier.md` — CQS: separate reads from writes

#### Group 6: Dealing with Generalization (techniques/06-XX)
Techniques for refactoring type hierarchies and shared behavior.
- `46-pull-up-method.md` — Move duplicated functions to shared parent/trait/interface
- `47-push-down-method.md` — Move specialized functions to specific types
- `48-pull-up-constructor-body.md` — Unify constructor/initialization logic
- `49-extract-superclass.md` — Create common parent for shared behavior
- `50-extract-interface.md` — Define a contract without implementation
- `51-collapse-hierarchy.md` — Merge unnecessary hierarchy levels
- `52-form-template-method.md` — Template Method pattern
- `53-replace-subclass-with-delegate.md` — Composition over inheritance
- `54-replace-superclass-with-delegate.md` — Replace extends with has-a
- `55-replace-inheritance-with-delegation.md` — General inheritance to delegation

#### Group 7: Additional Techniques (techniques/07-XX)
Cross-cutting techniques from both sources.
- `56-combine-functions-into-class.md` — Group functions that share data
- `57-combine-functions-into-transform.md` — Enrich read-only data
- `58-split-phase.md` — Separate code into processing phases
- `59-introduce-foreign-method.md` — Extend third-party types you can't modify
- `60-introduce-local-extension.md` — Wrapper or subclass for library extension
- `61-replace-error-code-with-exception.md` — Modernize error handling
- `62-replace-exception-with-test.md` — Don't use exceptions for control flow

### Reference files

| File | Content |
|---|---|
| `references/language-idioms.md` | Refactoring concept → {Python, TypeScript, Go, Rust} equivalents |
| `references/language-applicability.md` | 62-technique × language applicability matrix with alternatives |
| `references/java-notes.md` | Java-specific constraints, Java 8 vs 11+ notes, and the Java completion gate |
| `references/selection-heuristics.md` | Ordered decision rules when several techniques compete: conditionals tree, smell directionality, falsifiable micro-tests, inheritance→delegation triggers |
| `references/technique-to-pattern.md` | Which refactoring techniques land on which GoF pattern (Kerievsky bridge) |
