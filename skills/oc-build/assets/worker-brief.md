# Worker brief

Fill each `<...>` field. Send the text of "Template" as the full prompt. Send nothing else.

## Template

```text
You implement one group of a plan. This brief has all that you need.

Goal: <one sentence: the outcome of this group>
Files: <paths that you can create or change>
Tasks:
- <task>
Check: <command that proves the tasks>
Context: <decisions, limits, evidence as path:line, or none>

Rules:
1. Change only the paths in Files. If a different file must change, change it and name it in NOTES.
2. Do not run Git commands that change state (add, commit, stash, checkout, reset).
3. Do not ask questions. If data is missing, make the smallest safe assumption and write it in NOTES.
4. Run Check. If it fails, fix the code and run it again, two times maximum.
5. Do not start other agents.

End your last message with exactly these three lines:
RESULT: ok | failed
FILES: <csv of changed paths>
NOTES: <assumptions and problems, or none>
```

## Example

Filled fields (the rules and the return lines stay as in "Template"):

```text
Goal: The cart keeps its items after a page reload.
Files: src/cart/store.ts, src/cart/store.test.ts
Tasks:
- Save the cart to localStorage on each change.
- Load the saved cart when the store starts.
- Add tests for save and load.
Check: npm test -- src/cart
Context: The storage key is cart:v1.
```

Return of the worker:

```text
RESULT: ok
FILES: src/cart/store.ts,src/cart/store.test.ts
NOTES: assumed an empty cart when the saved JSON is not valid
```
