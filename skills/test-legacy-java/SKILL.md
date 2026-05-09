---
name: test-legacy-java
description: "Trigger: Java legacy code, código legado Java, JUnit, Mockito, characterization tests, seams, ApprovalTests. Test and break dependencies safely."
license: MIT
metadata:
  author: andresnator
  version: "2.1.0"
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

## Test Stack Detection

Before writing tests, inspect the target project's build tool and existing test dependencies. Detect these as independent facts: Java language level, JUnit family/version, Mockito artifacts/version, build dependency management, and whether ApprovalTests is already present. **Do not infer JUnit or Mockito from Java version alone.**

If dependencies are missing or unclear, read `references/dependency-setup.md` before adding imports, annotations, runners/extensions, or build snippets. For Golden Master or ApprovalTests work, read `references/approvaltests-setup.md` before generating or approving baseline files.

## How to Use This Skill

1. **Detect** the Java level, JUnit family, Mockito version, build tool, and dependency management independently
2. **Apply** the Legacy Code Change Algorithm (5 steps above)
3. **If stuck** testing something → read `references/quick-decision-flow.md` for the "I can't test X" decision tree with technique-to-file routing
4. **Select technique** from the reference files below based on your situation
5. **Apply incrementally**: small steps, test after each change, commit frequently

## Reference Files

Reference files contain technique examples or setup guidance:

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
| `references/dependency-setup.md` | Maven/Gradle setup, managed versions, Java/JUnit/Mockito compatibility | Setup |
| `references/approvaltests-setup.md` | ApprovalTests setup, reporters, scrubbers, CI, baseline safety | Setup |

## The Four Strategies for Breaking Dependencies

From Chapter 25. Organize your approach by choosing one of these four strategies:

| Strategy | Techniques | Best for |
|----------|-----------|----------|
| **Accept & Adapt** (don't change the signature) | Adapt Parameter, Primitivize Parameter, Preserve Signatures | When you can't change callers |
| **Subclass & Override** (inheritance) | Subclass and Override Method, Extract and Override Call/Factory/Getter | Fastest way to create seams |
| **Inject & Delegate** (composition) | Parameterize Constructor/Method, Extract Interface/Implementer | Architecturally cleanest |
| **Brute Force** (structural/global) | Introduce Static Setter, Replace Global Reference, Supersede Instance Variable | Last resort for Singletons |

## Rules for Generating Code

1. Always ask or detect Java level, JUnit family, Mockito version, and build tool before generating examples
2. Preserve the project's detected test stack unless a dependency change is explicitly needed and justified
3. Use Mockito versions compatible with the Java runtime: Mockito 3 for Java 8, Mockito 5 for Java 11+; check static/final mocking support before recommending it
4. In Java 11+, leverage `var` for local types in tests only when it matches project style
5. In Java 17+, use records for test DTOs where applicable and accepted by the project style
6. Include comments explaining which Feathers technique is being applied and the chapter reference
7. Each example must be complete and compilable (imports included)
8. Name tests descriptively: `testBehavior_whenCondition_thenResult`
9. When discovering bugs during characterization: document the bug as-is, do NOT fix it yet
10. Prefer Object Seams over other seam types — they are the cleanest in Java
11. Always mention whether you're applying Sensing or Separation when breaking a dependency
