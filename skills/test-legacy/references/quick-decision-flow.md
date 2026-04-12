# Quick Decision Flow: "I Can't Test X"

When the user says "I can't test X", follow this decision tree to identify the right technique.

## Can I instantiate the class/object?

**NO** →
- Constructor with heavy parameters → **Parameterize Constructor** or **Pass Null/None/undefined**
- Hidden dependencies (internal `new`/construction) → **Extract and Override Factory Method**
- Too many constructor params → **Pass Null/None** for unused ones
- Singleton/Global state → **Introduce Setter** or **Replace Global Reference**
- Long method with many locals → **Break Out Method Object**

## Can I run the method/function?

**NO** →
- Private/protected method → Make accessible for test (language-specific: package-private in Java, `_name` convention in Python, `@visibleForTesting` in Kotlin, `internal` in C#)
- Sealed/final class → **Adapt Parameter** or use wrapper
- Static/global function dependency → **Skin and Wrap the API**
- Invisible side effect → **Sensing** with Fake/Mock + **Extract and Override Call**

## Can I observe the results?

**NO** →
- Method returns void/None → Use **Sensing** — inject a Fake or Mock to capture the effect
- Effect goes to a global/static/module-level state → **Encapsulate Global Reference**
- Effect is invisible → Draw an **Effect Sketch** to find observation points

## Do I need to add new functionality?

**YES** →
- New logic in the middle of an existing method → **Sprout Method/Function**
- Original's dependencies are impossible → **Sprout Class/Module**
- Behavior before/after → **Wrap Method/Function**
- Decorate the entire class → **Wrap Class** (or decorator pattern)
- Can't modify the original at all → **Programming by Difference** (subclass/extend temporarily)

## Do I need to understand the code first?

**YES** →
- Use **Scratch Refactoring**: refactor aggressively on a throwaway branch to understand, then discard
- Draw an **Effect Sketch**: trace how changes propagate through variables, return values, and state
- List responsibilities: if you say "this module does X **and** Y **and** Z", you have 3 modules
- Then write **Characterization Tests**

## Do I need to change many classes/modules at once?

**YES** → Look for a **Pinch Point** — one function/class/module that exercises all the units you need to modify

## Is the code a 3rd-party API dependency?

**YES** → **Skin and Wrap the API** — create a thin interface/protocol + production wrapper
