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
  "Cover and Modify", "Edit and Pray", "Golden Master", "ApprovalTests", or similar techniques.
  Tambien se activa en castellano: "codigo sin tests", "no puedo testear esta clase", "codigo legado",
  "romper dependencias", "dependencias acopladas", "clase Dios", "test de caracterizacion",
  "metodo Sprout", "metodo Wrap", "extraer e implementar", "punto de pellizco", "costura",
  "cubrir y modificar", "editar y rezar", "codigo heredado", "hacer testeable",
  "golden master", "prueba de aprobacion", "TDD en codigo legado".
license: MIT
metadata:
  author: andresnator
  version: "2.0"
---

# Legacy Code Testing Skill (Java)

Battle-tested techniques for introducing tests into legacy Java code, based on Michael Feathers' "Working Effectively with Legacy Code." All examples use JUnit 4/5 and Mockito.

## Core Philosophy

**Legacy code = code without tests.** The methodology is **Cover and Modify** — the opposite of "Edit and Pray."

- **Edit and Pray**: Change the code carefully, test manually, hope nothing breaks. Slow, risky, fear-driven.
- **Cover and Modify**: Build a safety net of tests first ("the Vise"), then change with confidence.

The golden rule: **Cover → Modify → Refactor.**

## The Legacy Code Change Algorithm

Before any modification, follow these 5 steps:

1. **Identify change points** — Where do I need to touch the code?
2. **Find test points** — Where can I detect the behavior? (use Effect Sketches to trace impact)
3. **Break dependencies** — Two reasons: **Sensing** (to observe effects) and **Separation** (to run code in isolation). See `references/sensing-separation.md`
4. **Write characterization tests** — Document what the code does NOW, not what it should do. See `references/characterization-tests.md`
5. **Make changes and refactor** — Now it's safe

## The Seam Model

A **Seam** is a place where you can change the behavior of a program without editing the code at that place. Every seam has an **Enabling Point** — where you decide which behavior executes (production vs test).

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

## How to Use This Skill

1. **Detect** the Java and JUnit version (table above)
2. **Apply** the Legacy Code Change Algorithm (5 steps above)
3. **If stuck** testing something → read `references/quick-decision-flow.md` for the "I can't test X" decision tree with technique-to-file routing
4. **Select technique** from the reference files below based on your situation
5. **Apply incrementally**: small steps, test after each change, commit frequently

## Reference Files

Each reference file contains complete, compilable examples for each Java/JUnit combination:

| File | Content | Chapters |
|------|---------|----------|
| `references/characterization-tests.md` | Characterization tests, Golden Master, ApprovalTests | Ch 13, 22 |
| `references/sensing-separation.md` | Sensing vs Separation, Fakes vs Mocks | Ch 3 |
| `references/seam-model.md` | Object Seams, Link Seams, Enabling Points | Ch 4 |
| `references/dependency-breaking.md` | Parameterize Constructor, Extract Interface, Extract and Override, Adapt Parameter, Static Setter, Push Down Dependency | Ch 9, 25 |
| `references/pass-null-subclass-override.md` | Pass Null, Subclass and Override Method, Break Out Method Object | Ch 9, 25 |
| `references/method-object-skin-wrap.md` | Supersede Instance Variable, Primitivize Parameter, Skin and Wrap the API | Ch 9, 14, 25 |
| `references/sprout-wrap-techniques.md` | Sprout Method/Class, Wrap Method/Class | Ch 6 |
| `references/tdd-legacy.md` | TDD in Legacy Code, Programming by Difference, Lean on the Compiler | Ch 8, 23 |
| `references/advanced-patterns.md` | Pinch Points, Effect Sketches, God Class clustering, Hot Spots, Scratch Refactoring | Ch 11, 12, 16-17, 20-21 |
| `references/mockito-patterns.md` | Mockito patterns: verify, captor, spy, static mock, InOrder | Ch 5 |
| `references/quick-decision-flow.md` | "I can't test X" decision tree with technique-to-file routing | Ch 9, 25 |

## The Four Strategies for Breaking Dependencies

From Chapter 25. Organize your approach by choosing one of these four strategies:

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
