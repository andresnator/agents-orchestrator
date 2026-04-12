# Language-Specific Adaptation Guide

When translating Feathers' techniques to the target language, use these mappings. The original techniques are described in Java terms — this guide shows the idiomatic equivalent in each language.

## Python

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

## TypeScript / JavaScript

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

## C#

| Feathers Technique | C# Equivalent |
|---|---|
| Extract Interface | `interface` (identical concept) |
| Subclass and Override | Subclass + `override` (method must be `virtual`) |
| Parameterize Constructor | Constructor injection (often with DI container) |
| Static mock | Use wrapper class around static, or Moq + interfaces |
| Introduce Static Setter | Property with setter, or `internal` + `InternalsVisibleTo` |
| Adapt Parameter | Accept interface parameter |
| Pass Null | Pass `null` or use `Mock<T>().Object` with Moq |

## Go

| Feathers Technique | Go Equivalent |
|---|---|
| Extract Interface | Define interface (implicit — no `implements` keyword) |
| Subclass and Override | Embedding + method override on wrapper struct |
| Parameterize Constructor | Functional options pattern or struct with injectable fields |
| Static/Function mock | Replace `func` field on struct, or use interface |
| Introduce Static Setter | Package-level `var` + replace in test |
| Adapt Parameter | Accept interface (Go interfaces are implicit) |
| Pass Null | Pass `nil` for pointer/interface params |

## Rust

| Feathers Technique | Rust Equivalent |
|---|---|
| Extract Interface | Define `trait` |
| Subclass and Override | Implement trait differently for test struct |
| Parameterize Constructor | Generic with trait bound, or `impl Trait` parameter |
| Static mock | `mockall` crate, or `cfg(test)` conditional compilation |
| Link Seam | `cfg(test)` + test-only module implementations |
| Adapt Parameter | Accept `impl Trait` or generic parameter |
| Pass Null | Use `Option<T>` and pass `None` |
