# The Seam Model (Multi-Language)

A **Seam** is a place where you can change the behavior of a program without editing the code at that place. Every seam has an **Enabling Point** — where you decide which behavior executes (production vs test).

## Seam Types by Language Paradigm

| Seam Type | Mechanism | Languages | Enabling Point |
|-----------|-----------|-----------|----------------|
| **Object Seam** | Polymorphism — override/implement methods | Java, C#, Kotlin, Swift, PHP, Ruby | Constructor injection, DI container, factory |
| **Module/Import Seam** | Replace what a module imports | Python, TypeScript/JS, Go, Rust | Mock the import/module at test time |
| **Duck-Type Seam** | Pass any object with matching interface | Python, Ruby, JS/TS, Go (implicit interfaces) | Where the collaborator is passed |
| **Function Seam** | Replace a function reference | Go (func fields), JS/TS (callbacks), Python (first-class functions) | Where the function is assigned |
| **Link Seam** | Build/classpath swaps implementation | Java (Maven scope), C# (assembly), Rust (feature flags) | Build config |
| **Monkey-Patch Seam** | Modify objects/modules at runtime | Python, Ruby, JS | Test setup (monkeypatch, mock.patch) |
| **Preprocessing Seam** | Macros / compiler directives | C/C++, Rust (`cfg(test)`) | Compiler flags |

## Key Insight

The more dynamic the language, the more seam types you have available:
- **Static languages** (Java, C#, Go, Rust): Object Seams and Interface Seams are primary. Need explicit refactoring to create seams.
- **Dynamic languages** (Python, Ruby, JS): Monkey-patching and Module Seams give you "free" seams. But prefer Object Seams for maintainability — monkey-patches are powerful but fragile.

## Choosing a Seam Type

Start with **Object/Interface Seams** in any language — they are the cleanest, most maintainable, and most portable. Fall back to Module/Import Seams when you cannot change the constructor or the dependency is a module-level function. Use Monkey-Patch Seams only as a last resort for code you truly cannot restructure — they work fast but create brittle tests that break when internals change.
