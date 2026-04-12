---
name: test-legacy
description: |
  Multi-language legacy code testing techniques from Michael Feathers' "Working Effectively with Legacy Code."
  Detects the project's language and test framework to generate idiomatic tests. Works with Java,
  Python, TypeScript, JavaScript, C#, Go, Kotlin, Ruby, PHP, Rust, Swift, and more.
  Use this skill whenever the user struggles to test existing code — even if they don't mention
  Feathers by name. Triggers: code without tests, untestable classes, coupled dependencies, God
  classes, breaking dependencies, characterization tests, Sprout/Wrap methods, Seams, Sensing,
  Separation, Golden Master, Effect Sketches, Pinch Points, or any situation where legacy code
  blocks testing. Also triggers on "código sin tests", "código legado", "no puedo testear",
  "romper dependencias", "hacer testeable", "test de caracterización".
  For Java-specific JUnit/Mockito version matrices and compiled reference examples, use test-legacy-java.
license: MIT
metadata:
  author: andresnator
  version: "2.1"
---

# Legacy Code Testing Skill (Multi-Language)

Battle-tested techniques for introducing tests into legacy code in **any language**, based on Michael Feathers' "Working Effectively with Legacy Code."

## Step 0: Detect Language and Test Framework

Before generating any code, detect the project's language and testing ecosystem:

| Language | Test Frameworks | Mocking Tools | Seam Style |
|----------|----------------|---------------|------------|
| **Java** | JUnit 4/5 | Mockito, PowerMock | Object Seams (polymorphism), Link Seams (classpath) |
| **Python** | pytest, unittest | unittest.mock, pytest-mock, monkeypatch | Object Seams (duck typing), Monkey-patching, Module Seams (imports) |
| **TypeScript/JS** | Jest, Vitest, Mocha | jest.mock, jest.spyOn, sinon, vi.mock | Module Seams (import mocking), Object Seams (prototype/class) |
| **C#** | xUnit, NUnit, MSTest | Moq, NSubstitute, FakeItEasy | Object Seams (interfaces/virtual), Link Seams (assembly) |
| **Go** | testing (stdlib) | testify/mock, gomock, interfaces | Interface Seams (implicit interfaces), Function Seams (func fields) |
| **Kotlin** | JUnit 5, Kotest | MockK, Mockito-Kotlin | Object Seams, Extension Seams |
| **Ruby** | RSpec, Minitest | rspec-mocks, mocha | Object Seams (open classes), Module Seams (monkey-patch) |
| **PHP** | PHPUnit, Pest | Mockery, PHPUnit mocks, Prophecy | Object Seams (interfaces), Link Seams (autoloader) |
| **Rust** | #[test], cargo test | mockall, mockito (trait-based) | Trait Seams, Feature-flag Seams (cfg), Module Seams |
| **Swift** | XCTest, Quick/Nimble | Protocol-based mocking | Protocol Seams (protocols = interfaces) |

**Detection heuristic**: Check project files — `pom.xml`/`build.gradle` → Java, `package.json` → TS/JS, `pyproject.toml`/`requirements.txt` → Python, `*.csproj` → C#, `go.mod` → Go, `Cargo.toml` → Rust, `Gemfile` → Ruby, `composer.json` → PHP, `Package.swift` → Swift.

If the language is **Java** and the user needs version-specific JUnit 4/5/Mockito matrices, delegate to the `test-legacy-java` skill — it has 10 detailed reference files with compiled examples per Java version.

## Contents

| Section | What it covers |
|---------|---------------|
| [Core Philosophy](#core-philosophy) | Cover and Modify vs Edit and Pray |
| [Legacy Code Change Algorithm](#the-legacy-code-change-algorithm) | 5-step process before any modification |
| [The Seam Model (Multi-Language)](#the-seam-model-multi-language) | Seam types across languages |
| [Quick Decision Flow](#quick-decision-flow) | "I can't test X" decision tree |
| [Four Strategies for Breaking Dependencies](#the-four-strategies-for-breaking-dependencies) | Accept/Subclass/Inject/Brute Force |
| [Language-Specific Adaptation Guide](#language-specific-adaptation-guide) | How to translate techniques per language |
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
3. **Break dependencies** — Two reasons: **Sensing** (to observe effects) and **Separation** (to run code in isolation)
4. **Write characterization tests** — Document what the code does NOW, not what it should do
5. **Make changes and refactor** — Now it's safe

## The Seam Model (Multi-Language)

A **Seam** is a place where you can change the behavior of a program without editing the code at that place. Every seam has an **Enabling Point** — where you decide which behavior executes (production vs test).

### Seam Types by Language Paradigm

| Seam Type | Mechanism | Languages | Enabling Point |
|-----------|-----------|-----------|----------------|
| **Object Seam** | Polymorphism — override/implement methods | Java, C#, Kotlin, Swift, PHP, Ruby | Constructor injection, DI container, factory |
| **Module/Import Seam** | Replace what a module imports | Python, TypeScript/JS, Go, Rust | Mock the import/module at test time |
| **Duck-Type Seam** | Pass any object with matching interface | Python, Ruby, JS/TS, Go (implicit interfaces) | Where the collaborator is passed |
| **Function Seam** | Replace a function reference | Go (func fields), JS/TS (callbacks), Python (first-class functions) | Where the function is assigned |
| **Link Seam** | Build/classpath swaps implementation | Java (Maven scope), C# (assembly), Rust (feature flags) | Build config |
| **Monkey-Patch Seam** | Modify objects/modules at runtime | Python, Ruby, JS | Test setup (monkeypatch, mock.patch) |
| **Preprocessing Seam** | Macros / compiler directives | C/C++, Rust (`cfg(test)`) | Compiler flags |

### Key Insight

The more dynamic the language, the more seam types you have available:
- **Static languages** (Java, C#, Go, Rust): Object Seams and Interface Seams are primary. Need explicit refactoring to create seams.
- **Dynamic languages** (Python, Ruby, JS): Monkey-patching and Module Seams give you "free" seams. But prefer Object Seams for maintainability — monkey-patches are powerful but fragile.

## Quick Decision Flow

When the user says "I can't test X", follow this tree:

### Can I instantiate the class/object?
- **NO** →
  - Constructor with heavy parameters → **Parameterize Constructor** or **Pass Null/None/undefined**
  - Hidden dependencies (internal `new`/construction) → **Extract and Override Factory Method**
  - Too many constructor params → **Pass Null/None** for unused ones
  - Singleton/Global state → **Introduce Setter** or **Replace Global Reference**
  - Long method with many locals → **Break Out Method Object**

### Can I run the method/function?
- **NO** →
  - Private/protected method → Make accessible for test (language-specific: package-private in Java, `_name` convention in Python, `@visibleForTesting` in Kotlin, `internal` in C#)
  - Sealed/final class → **Adapt Parameter** or use wrapper
  - Static/global function dependency → **Skin and Wrap the API**
  - Invisible side effect → **Sensing** with Fake/Mock + **Extract and Override Call**

### Can I observe the results?
- **NO** →
  - Method returns void/None → Use **Sensing** — inject a Fake or Mock to capture the effect
  - Effect goes to a global/static/module-level state → **Encapsulate Global Reference**
  - Effect is invisible → Draw an **Effect Sketch** to find observation points

### Do I need to add new functionality?
- **YES** →
  - New logic in the middle of an existing method → **Sprout Method/Function**
  - Original's dependencies are impossible → **Sprout Class/Module**
  - Behavior before/after → **Wrap Method/Function**
  - Decorate the entire class → **Wrap Class** (or decorator pattern)
  - Can't modify the original at all → **Programming by Difference** (subclass/extend temporarily)

### Do I need to understand the code first?
- **YES** →
  - Use **Scratch Refactoring**: refactor aggressively on a throwaway branch to understand, then discard
  - Draw an **Effect Sketch**: trace how changes propagate through variables, return values, and state
  - List responsibilities: if you say "this module does X **and** Y **and** Z", you have 3 modules
  - Then write **Characterization Tests**

### Do I need to change many classes/modules at once?
- **YES** → Look for a **Pinch Point** — one function/class/module that exercises all the units you need to modify

### Is the code a 3rd-party API dependency?
- **YES** → **Skin and Wrap the API** — create a thin interface/protocol + production wrapper

## The Four Strategies for Breaking Dependencies

Organize your approach by choosing one of these four strategies (from Chapter 25):

| Strategy | Techniques | Best for |
|----------|-----------|----------|
| **Accept & Adapt** (don't change the signature) | Adapt Parameter, Primitivize Parameter, Preserve Signatures | When you can't change callers |
| **Subclass & Override** (inheritance/extension) | Subclass and Override Method, Extract and Override Call/Factory/Getter | Fastest way to create seams in OO languages |
| **Inject & Delegate** (composition) | Parameterize Constructor/Method, Extract Interface/Protocol | Architecturally cleanest, works in ALL languages |
| **Brute Force** (structural/global) | Introduce Setter, Replace Global Reference, Monkey-patch | Last resort — for Singletons, globals, module state |

## Language-Specific Adaptation Guide

When translating Feathers' techniques to the target language, use this mapping:

### Python
| Feathers Technique | Python Equivalent |
|---|---|
| Extract Interface | Define a Protocol (typing.Protocol) or ABC |
| Subclass and Override | Subclass and override (identical — Python has no `final`) |
| Extract and Override Factory Method | Override `__init__` helper or use factory function |
| Parameterize Constructor | `__init__` with default arguments or dependency injection |
| Static mock | `unittest.mock.patch` or `monkeypatch.setattr` |
| Introduce Static Setter | Module-level variable + setter, or `monkeypatch` in tests |
| Adapt Parameter | Accept duck-typed parameter (no interface needed) |
| Pass Null | Pass `None` with appropriate handling |

### TypeScript / JavaScript
| Feathers Technique | TS/JS Equivalent |
|---|---|
| Extract Interface | TypeScript `interface` or duck typing in JS |
| Subclass and Override | `extends` + override (TS: `override` keyword) |
| Extract and Override Factory Method | Override factory method or use injectable factory function |
| Parameterize Constructor | Constructor with optional deps / default parameter values |
| Static mock | `jest.mock('module')`, `vi.mock('module')`, or `jest.spyOn` |
| Introduce Static Setter | Module-level export + override in test (`jest.mock`) |
| Link Seam | `jest.mock` / `vi.mock` replaces entire modules |
| Pass Null | Pass `null`, `undefined`, or `{} as Type` partial mock |

### C#
| Feathers Technique | C# Equivalent |
|---|---|
| Extract Interface | `interface` (identical concept) |
| Subclass and Override | Subclass + `override` (method must be `virtual`) |
| Parameterize Constructor | Constructor injection (often with DI container) |
| Static mock | Use wrapper class around static, or Moq + interfaces |
| Introduce Static Setter | Property with setter, or `internal` + `InternalsVisibleTo` |
| Adapt Parameter | Accept interface parameter |
| Pass Null | Pass `null` or use `Mock<T>().Object` with Moq |

### Go
| Feathers Technique | Go Equivalent |
|---|---|
| Extract Interface | Define interface (implicit — no `implements` keyword) |
| Subclass and Override | Embedding + method override on wrapper struct |
| Parameterize Constructor | Functional options pattern or struct with injectable fields |
| Static/Function mock | Replace `func` field on struct, or use interface |
| Introduce Static Setter | Package-level `var` + replace in test |
| Adapt Parameter | Accept interface (Go interfaces are implicit) |
| Pass Null | Pass `nil` for pointer/interface params |

### Rust
| Feathers Technique | Rust Equivalent |
|---|---|
| Extract Interface | Define `trait` |
| Subclass and Override | Implement trait differently for test struct |
| Parameterize Constructor | Generic with trait bound, or `impl Trait` parameter |
| Static mock | `mockall` crate, or `cfg(test)` conditional compilation |
| Link Seam | `cfg(test)` + test-only module implementations |
| Adapt Parameter | Accept `impl Trait` or generic parameter |
| Pass Null | Use `Option<T>` and pass `None` |

## Rules for Generating Code

1. **Always detect the project's language and test framework** before generating examples — check project files (`pom.xml`, `package.json`, `pyproject.toml`, `go.mod`, `*.csproj`, `Cargo.toml`, etc.)
2. **Generate idiomatic code** for the detected language — don't write Java patterns in Python or vice versa
3. **Use the language's standard mocking tools** (see Step 0 table)
4. **Include comments** explaining which Feathers technique is being applied and the chapter reference
5. **Each example must be complete and runnable** (imports/requires included)
6. **Name tests descriptively** using the language's convention:
   - Java: `testBehavior_whenCondition_thenResult`
   - Python: `test_behavior_when_condition_then_result`
   - TypeScript/JS: `it('should behavior when condition')` or `test('behavior when condition')`
   - C#: `Behavior_WhenCondition_ThenResult`
   - Go: `TestBehavior_WhenCondition`
   - Rust: `fn test_behavior_when_condition()`
7. **When discovering bugs during characterization**: document the bug as-is, do NOT fix it yet
8. **Prefer Object/Interface Seams** over monkey-patching or module-mocking — they are the cleanest across all languages
9. **Always mention** whether you're applying **Sensing** or **Separation** when breaking a dependency
10. **If the language is Java** and the user needs version-specific JUnit 4 vs 5 vs Mockito compatibility matrices, reference the `test-legacy-java` skill

## Trigger Keywords (Castellano)

This skill also activates on Spanish triggers including but not limited to: "código sin tests", "no puedo testear esta clase", "código legado", "romper dependencias", "dependencias acopladas", "clase Dios", "test de caracterización", "método Sprout", "método Wrap", "extraer e implementar", "punto de pellizco", "costura", "cubrir y modificar", "editar y rezar", "código heredado", "hacer testeable", "añadir tests a código existente", "no tiene cobertura", "sin pruebas unitarias", "golden master", "prueba de aprobación", "envolver API externa", "aislar API de terceros", "TDD en código legado", "detectar efectos secundarios", "aislar código para testear", "dependencias ocultas en el constructor", "este código es imposible de testear", "cómo meto tests a este código", "clase monolítica sin tests".
