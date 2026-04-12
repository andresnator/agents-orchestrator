---
name: test-legacy-java
description: |
  Java-specific testing techniques for legacy code based on "Working Effectively with Legacy Code" by Michael Feathers.
  Use this skill when the user needs to write Java tests for existing code without coverage, break
  dependencies to make Java code testable, apply Characterization Tests with JUnit, use Sprout/Wrap
  techniques to safely add functionality, deal with Singletons/statics/final classes in Java tests,
  find Seams in Java code, apply Sensing or Separation to isolate behavior, use TDD in legacy Java
  contexts, or any situation where legacy Java code hinders testing.
  Covers JUnit 4, JUnit 5, Mockito, and Java versions from 8 through 21+.
  This skill is Java-only. For other languages (Python, TypeScript, C#, Go, etc.), use the test-legacy skill instead.
  Also applies when the user mentions "code without tests", "I can't test this class", "coupled
  dependencies", "God class", "break dependencies", "characterization test", "Sprout Method",
  "Wrap Method", "Extract and Override", "Pinch Point", "Seam", "Sensing", "Separation",
  "Programming by Difference", "Pass Null", "Scratch Refactoring", "Effect Sketch",
  "Cover and Modify", "Edit and Pray", "Golden Master", "golden match", "ApprovalTests",
  "Approval Tests", "approval testing", "Approvals.verify", "CombinationApprovals",
  "verifyAllCombinations", or similar techniques from Feathers' book.
  También se activa en castellano: "código sin tests", "no puedo testear esta clase", "código legado",
  "romper dependencias", "dependencias acopladas", "clase Dios", "test de caracterización",
  "método Sprout", "método Wrap", "extraer e implementar", "punto de pellizco", "costura",
  "detección", "separación", "programar por diferencia", "pasar null", "refactorización exploratoria",
  "diagrama de efectos", "cubrir y modificar", "editar y rezar", "código heredado", "código legacy",
  "hacer testeable", "añadir tests a código existente", "no tiene cobertura", "sin pruebas unitarias",
  "golden master", "prueba de aprobación", "archivo aprobado", "test de aprobación",
  "verificar llamadas con Mockito", "capturar argumentos", "espía de Mockito", "mock estático",
  "envolver API externa", "aislar API de terceros", "skin and wrap", "superseder variable de instancia",
  "primitivizar parámetro", "punto de costura", "tipo de costura", "punto de habilitación",
  "cambiar comportamiento sin editar el código", "subclasificar y sobrescribir",
  "romper método en objeto", "constructor con demasiados parámetros",
  "TDD en código legado", "apoyarse en el compilador", "desarrollo guiado por tests en legacy",
  "detectar efectos secundarios", "aislar código para testear", "observar efectos ocultos",
  "separar para testear", "no puedo instanciar la clase en el test",
  "dependencias ocultas en el constructor", "este código es imposible de testear",
  "cómo meto tests a este código", "efectos secundarios invisibles",
  "clase monolítica sin tests", "método con demasiadas líneas sin cobertura".
license: MIT
metadata:
  author: andresnator
  version: "1.0"
---

# Legacy Code Testing Skill (Java)

Battle-tested techniques for introducing tests into legacy Java code, based on Michael Feathers' "Working Effectively with Legacy Code." All examples use JUnit 4/5 and Mockito.

## Contents

| Section | What it covers |
|---------|---------------|
| [Core Philosophy](#core-philosophy) | Cover and Modify vs Edit and Pray |
| [Legacy Code Change Algorithm](#the-legacy-code-change-algorithm) | 5-step process before any modification |
| [The Seam Model](#the-seam-model) | Object / Link / Preprocessing seams |
| [Java & JUnit Version Selection](#java-and-junit-version-selection) | JUnit 4 vs 5, Mockito compatibility |
| [Reference Files](#reference-files) | Index of all 10 reference files with chapter mapping |
| [Quick Decision Flow](#quick-decision-flow) | "I can't test X" decision tree |
| [Four Strategies for Breaking Dependencies](#the-four-strategies-for-breaking-dependencies) | Accept/Subclass/Inject/Brute Force |
| [Rules for Generating Code](#rules-for-generating-code) | Code generation checklist |

## Core Philosophy

**Legacy code = code without tests.** The methodology is **Cover and Modify** — the opposite of "Edit and Pray."

- **Edit and Pray**: Change the code carefully, test manually, hope nothing breaks. Slow, risky, fear-driven.
- **Cover and Modify**: Build a safety net of tests first ("the Vise"), then change with confidence. Fast feedback, evidence-based.

The golden rule: **Cover → Modify → Refactor.**

1. **Cover**: Write characterization tests to pin down current behavior (the code IS the specification)
2. **Modify**: Make the required change
3. **Refactor**: Improve the design with tests protecting you

## The Legacy Code Change Algorithm

Before any modification, follow these 5 steps:

1. **Identify change points** — Where do I need to touch the code?
2. **Find test points** — Where can I detect the behavior? (use Effect Sketches to trace impact)
3. **Break dependencies** — Two reasons: **Sensing** (to observe effects) and **Separation** (to run code in isolation). See `references/sensing-separation.md`
4. **Write characterization tests** — Document what the code does NOW, not what it should do. See `references/characterization-tests.md`
5. **Make changes and refactor** — Now it's safe

## The Seam Model

A **Seam** is a place where you can change the behavior of a program without editing the code at that place. Every seam has an **Enabling Point** — where you decide which behavior executes (production vs test).

**Types of Seams** (most to least common in Java):

| Type | How it works | Enabling Point | When to use |
|------|-------------|----------------|-------------|
| **Object Seam** | Polymorphism — override methods in subclasses | Where the object is created/injected | Default choice in OO code |
| **Link Seam** | Classpath/build config swaps implementations | Build script, Maven scope | Test-scope dependencies |
| **Preprocessing Seam** | Macros (`#define`) | Compiler definitions | C/C++ only |

For detailed examples, see `references/seam-model.md`.

## Java and JUnit Version Selection

Before generating code, determine the project's Java and JUnit version:

| Aspect | Java 8 + JUnit 4 | Java 11+ + JUnit 5 | Java 17+ + JUnit 5 |
|--------|-------------------|---------------------|---------------------|
| Imports | `org.junit.Test` | `org.junit.jupiter.api.Test` | Same + records, sealed |
| Assertions | `Assert.assertEquals` | `Assertions.assertEquals` | Same |
| Setup | `@Before/@After` | `@BeforeEach/@AfterEach` | Same |
| Runner | `@RunWith` | `@ExtendWith` | Same |
| Mockito | `@RunWith(MockitoJUnitRunner.class)` | `@ExtendWith(MockitoExtension.class)` | Same |
| Static mock | PowerMock required | `mockStatic()` (mockito-inline) | Same |
| Lambdas | Yes | Yes + var | Yes + patterns |

## Reference Files

Each reference file contains complete, compilable examples for each Java/JUnit combination:

| File | Content | Chapters |
|------|---------|----------|
| `references/characterization-tests.md` | Characterization tests, Golden Master, ApprovalTests | Ch 13, 22 |
| `references/sensing-separation.md` | Sensing vs Separation, Fakes vs Mocks | Ch 3 |
| `references/seam-model.md` | Object Seams, Link Seams, Enabling Points | Ch 4 |
| `references/dependency-breaking.md` | Core techniques: Parameterize Constructor, Extract Interface, Extract and Override, Adapt Parameter, Static Setter, Push Down Dependency | Ch 9, 25 |
| `references/pass-null-subclass-override.md` | Pass Null, Subclass and Override Method, Break Out Method Object | Ch 9, 25 |
| `references/method-object-skin-wrap.md` | Supersede Instance Variable, Primitivize Parameter, Skin and Wrap the API | Ch 9, 14, 25 |
| `references/sprout-wrap-techniques.md` | Sprout Method/Class, Wrap Method/Class | Ch 6 |
| `references/tdd-legacy.md` | TDD in Legacy Code, Programming by Difference, Lean on the Compiler | Ch 8, 23 |
| `references/advanced-patterns.md` | Pinch Points, Effect Sketches, God Class clustering, Hot Spots, Scratch Refactoring | Ch 11, 12, 16, 17, 20, 21 |
| `references/mockito-patterns.md` | Mockito patterns: verify, captor, spy, static mock, InOrder | Ch 5 |

## Quick Decision Flow

When the user says "I can't test X", follow this tree:

### Can I instantiate the class?
- **NO** →
  - Constructor with heavy parameters → **Parameterize Constructor** or **Pass Null** (`references/dependency-breaking.md`, `references/pass-null-subclass-override.md`)
  - Hidden dependencies (internal `new`) → **Extract and Override Factory Method** (`references/dependency-breaking.md`)
  - Too many constructor params (onion) → **Pass Null** for unused ones (`references/pass-null-subclass-override.md`)
  - Singleton/Global → **Introduce Static Setter** or **Replace Global Reference with Getter** (`references/dependency-breaking.md`)
  - Long method with many locals → **Break Out Method Object** (`references/pass-null-subclass-override.md`)

### Can I run the method?
- **NO** →
  - Private method → Change to package-private or **Extract Class**
  - Final class → **Adapt Parameter** (`references/dependency-breaking.md`)
  - Static method dependency → **Skin and Wrap the API** (`references/method-object-skin-wrap.md`)
  - Invisible side effect → **Sensing** with Fake/Mock (`references/sensing-separation.md`) + **Extract and Override Call** (`references/dependency-breaking.md`)

### Can I observe the results?
- **NO** →
  - Method returns void → Use **Sensing** — inject a Fake or Mock to capture the effect (`references/sensing-separation.md`)
  - Effect goes to a global/static → **Encapsulate Global Reference** (`references/dependency-breaking.md`)
  - Effect is invisible → Draw an **Effect Sketch** to find observation points (`references/advanced-patterns.md`)

### Do I need to add new functionality?
- **YES** →
  - New logic in the middle of an existing method → **Sprout Method** (`references/sprout-wrap-techniques.md`)
  - Original's dependencies are impossible → **Sprout Class** (`references/sprout-wrap-techniques.md`)
  - Behavior before/after → **Wrap Method** (`references/sprout-wrap-techniques.md`)
  - Decorate the entire class → **Wrap Class** (`references/sprout-wrap-techniques.md`)
  - Can't modify the original at all → **Programming by Difference** (subclass temporarily) (`references/tdd-legacy.md`)

### Do I need to understand the code first?
- **YES** →
  - Use **Scratch Refactoring**: refactor aggressively on a throwaway branch to understand, then discard (`references/advanced-patterns.md`)
  - Draw an **Effect Sketch**: trace how changes propagate through variables, return values, and state
  - List responsibilities: if you say "this class does X **and** Y **and** Z", you have 3 classes
  - Then write **Characterization Tests** (`references/characterization-tests.md`)

### Do I need to change many classes at once?
- **YES** → Look for a **Pinch Point** — one method/class that exercises all the classes you need to modify (`references/advanced-patterns.md`)

### Is the code a 3rd-party API dependency?
- **YES** → **Skin and Wrap the API** — create a thin interface + production wrapper (`references/method-object-skin-wrap.md`)

## The Four Strategies for Breaking Dependencies

Organize your approach by choosing one of these four strategies (from Chapter 25):

| Strategy | Techniques | Best for |
|----------|-----------|----------|
| **Accept & Adapt** (don't change the signature) | Adapt Parameter, Primitivize Parameter, Preserve Signatures | When you can't change callers |
| **Subclass & Override** (inheritance) | Subclass and Override Method, Extract and Override Call/Factory/Getter | Fastest way to create seams |
| **Inject & Delegate** (composition) | Parameterize Constructor/Method, Extract Interface/Implementer | Architecturally cleanest |
| **Brute Force** (structural/global) | Introduce Static Setter, Replace Global Reference, Supersede Instance Variable | Last resort for Singletons |

## Rules for Generating Code

1. Always ask or detect the Java and JUnit version before generating examples
2. Use the compatible Mockito version (Mockito 4+ for JUnit 5, Mockito 2-3 for JUnit 4)
3. In Java 11+, leverage `var` for local types in tests
4. In Java 17+, use records for test DTOs and sealed interfaces where applicable
5. Include comments explaining which Feathers technique is being applied and the chapter reference
6. Each example must be complete and compilable (imports included)
7. Name tests descriptively: `testBehavior_whenCondition_thenResult`
8. When discovering bugs during characterization: document the bug as-is, do NOT fix it yet
9. Prefer Object Seams over other seam types — they are the cleanest in Java
10. Always mention whether you're applying Sensing or Separation when breaking a dependency
