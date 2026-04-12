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
  blocks testing. Also triggers on "codigo sin tests", "codigo legado", "no puedo testear",
  "romper dependencias", "hacer testeable", "test de caracterizacion".
  For Java-specific JUnit/Mockito version matrices and compiled reference examples, use test-legacy-java.
license: MIT
metadata:
  author: andresnator
  version: "3.0"
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

If the language is **Java** and the user needs version-specific JUnit 4/5/Mockito matrices, delegate to the `test-legacy-java` skill.

## Core Philosophy

**Legacy code = code without tests.** The methodology is **Cover and Modify** — the opposite of "Edit and Pray."

- **Edit and Pray**: Change the code carefully, test manually, hope nothing breaks. Slow, risky, fear-driven.
- **Cover and Modify**: Build a safety net of tests first ("the Vise"), then change with confidence.

The golden rule: **Cover → Modify → Refactor.**

## The Legacy Code Change Algorithm

Before any modification, follow these 5 steps:

1. **Identify change points** — Where do I need to touch the code?
2. **Find test points** — Where can I detect the behavior? (use Effect Sketches to trace impact)
3. **Break dependencies** — Two reasons: **Sensing** (to observe effects) and **Separation** (to run code in isolation)
4. **Write characterization tests** — Document what the code does NOW, not what it should do
5. **Make changes and refactor** — Now it's safe

## How to Use This Skill

1. **Detect** the language and test framework (Step 0 table above)
2. **Apply** the Legacy Code Change Algorithm (5 steps above)
3. **If stuck** testing something → read `references/quick-decision-flow.md` for the "I can't test X" decision tree
4. **For seam identification** → read `references/seam-model.md` to find where to inject test behavior
5. **For language-specific patterns** → read `references/language-adaptations.md` for Feathers-to-language mappings
6. **For strategy selection** → read `references/four-strategies.md` to choose the right dependency-breaking approach

## Reference Files

| File | Content | Chapters |
|------|---------|----------|
| `references/seam-model.md` | Seam types across language paradigms (7 types), enabling points, static vs dynamic insight | Ch 4 |
| `references/quick-decision-flow.md` | "I can't test X" decision tree: instantiate, run, observe, add functionality, understand, many classes, 3rd-party | Ch 9, 25 |
| `references/language-adaptations.md` | Feathers-to-language mapping tables for Python, TypeScript/JS, C#, Go, Rust | All |
| `references/four-strategies.md` | Accept & Adapt / Subclass & Override / Inject & Delegate / Brute Force with language considerations | Ch 25 |

## Rules for Generating Code

1. **Always detect** the project's language and test framework before generating examples
2. **Generate idiomatic code** for the detected language — don't write Java patterns in Python
3. **Use the language's standard mocking tools** (see Step 0 table)
4. **Include comments** explaining which Feathers technique is being applied and the chapter reference
5. **Each example must be complete and runnable** (imports/requires included)
6. **Name tests descriptively** using the language's convention (Java: `testBehavior_whenCondition`, Python: `test_behavior_when_condition`, TS/JS: `it('should behavior when condition')`, Go: `TestBehavior_WhenCondition`, Rust: `fn test_behavior_when_condition()`)
7. **When discovering bugs during characterization**: document the bug as-is, do NOT fix it yet
8. **Prefer Object/Interface Seams** over monkey-patching or module-mocking — cleanest across all languages
9. **Always mention** whether you're applying **Sensing** or **Separation** when breaking a dependency
10. **If the language is Java**, reference the `test-legacy-java` skill for version-specific examples

## Key Principles

1. **Cover before you Modify** — tests first, always. The code IS the specification.
2. **Prefer Object/Interface Seams** — cleanest across all languages, most maintainable.
3. **Name the reason** — always state whether you're applying Sensing or Separation when breaking a dependency.
4. **Idiomatic per language** — don't write Java patterns in Python or Go patterns in Rust.
5. **Characterization tests document what IS, not what should be** — if you find a bug, document it, don't fix it yet.
