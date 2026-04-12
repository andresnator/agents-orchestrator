# The Four Strategies for Breaking Dependencies

From Chapter 25 of "Working Effectively with Legacy Code." Organize your approach by choosing one of these four strategies:

| Strategy | Techniques | Best for |
|----------|-----------|----------|
| **Accept & Adapt** (don't change the signature) | Adapt Parameter, Primitivize Parameter, Preserve Signatures | When you can't change callers |
| **Subclass & Override** (inheritance/extension) | Subclass and Override Method, Extract and Override Call/Factory/Getter | Fastest way to create seams in OO languages |
| **Inject & Delegate** (composition) | Parameterize Constructor/Method, Extract Interface/Protocol | Architecturally cleanest, works in ALL languages |
| **Brute Force** (structural/global) | Introduce Setter, Replace Global Reference, Monkey-patch | Last resort — for Singletons, globals, module state |

## When to Choose Which Strategy

- **Start with Inject & Delegate** — it produces the cleanest architecture and works across all languages and paradigms. If you can change the constructor or method signature, this is the default.
- **Use Accept & Adapt** when callers are numerous or external and you cannot change signatures. Adapt the parameter type or primitivize it so the method can be tested without its original collaborator.
- **Use Subclass & Override** when you need a seam quickly in OO code and the class is not `final`/`sealed`. This is the fastest way to break a dependency for testing, even if the design is not ideal long-term.
- **Use Brute Force** only when the dependency is a Singleton, global variable, or module-level state that cannot be injected. Clean it up later once tests are in place.

## Language Considerations

In **static OO languages** (Java, C#, Kotlin), all four strategies apply directly. In **dynamic languages** (Python, Ruby, JS), monkey-patching often makes Brute Force trivially easy — but resist the temptation and prefer Inject & Delegate for maintainability. In **Go**, implicit interfaces make Inject & Delegate especially natural. In **Rust**, trait-based injection is the primary mechanism; Brute Force maps to `cfg(test)` conditional compilation.
