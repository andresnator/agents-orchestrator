# Deep Plan

Deep mode of `oc-plan`. The rules and "Plan format" of `SKILL.md` apply. This file adds the deep steps. Do steps 1, 2, and 5 always. Do step 3 only for a discovery and step 4 only for a refactor or hardening plan.

## 1. Pick the output

One run writes one file.

| Output | When | Path |
| --- | --- | --- |
| Plan (default) | You can state the goal in one sentence. | `.ai/plans/<slug>.md` |
| Discovery (Wayfinder) | The user says `wayfinder` or `explore an idea`, or the destination is not decided. | `.ai/discoveries/<slug>.md` |

If the output is not clear, write a plan and say so in one line.

## 2. Collect evidence

1. Read the implementations, callers, contracts, tests, and tool versions that the change touches.
2. For history, use read-only `git log`. Use repository evidence only, not the web.
3. Only for an area too large to read yourself, send research briefs to `scout` subagents in parallel. Three briefs maximum, each with a different question. If `scout` is not available, use the built-in `general`.
4. Write each fact that changes execution in `## Notes` as `path:line`.

The brief is self-contained. Send this text only:

```text
Read-only research. Do not edit files. Do not ask questions.
Repository: <absolute path>
Question: <one question>
Look in: <paths or globs>
Return: seven findings maximum, one per line, as `<path:line> <fact>`.
Then one line: `GAPS: <what you did not find, or none>`.
```

A brief that returns gaps does not stop the plan. Read the missing part yourself, or write a `hypothesis`.

## 3. Discovery only: Wayfinder

1. Fill `assets/discovery-template.md` with the destination, evidence, decisions, open questions, and next step.
2. Save it to `.ai/discoveries/<slug>.md`. To continue a discovery, update the path the user gives.
3. When the destination and the main decisions are clear, suggest `convert this discovery into a plan`.

To convert, read the discovery, then write a plan. Each open question that stays becomes an assumption in `## Notes`.

## 4. Refactor or hardening plan only

Add these lines to `## Notes`:

- Risk: `low`, `medium`, `high`, or `critical`, with the evidence.
- In-scope files and out-of-scope work.
- Churn from `git log`: files that change frequently come first.

Order the groups: tests and seams that protect the code first, then the restructuring. Put a behavior change in its own group. Groups that change different callers get different `Files:` and the same dependency, so they can run in parallel.

Optional lens analysis, for medium risk or higher: send one `scout` this brief. For critical risk, you can send two with different lens ids.

```text
Load oc-refactor in lens mode. Input: target=<path> target_slug=<slug> unit=<slug> lens=<lens> lenses=<csv|none> skills=none focus=<text> max=7
```

Fill each field. `target_slug` and `unit` are kebab-case names of the target. Use `lenses=none` when one lens is sufficient. Lens ids: `srp`, `dry`, `kiss`, `ocp`, `dip`, `coupling`, `big-o`, `god-object`, `spaghetti`, `logging`, `preconditions`. Use the findings as evidence in `## Notes`.

## 5. Check before you save

1. Walk `references/edge-validation.md`. Give each edge its destination.
2. Make sure `Done means` has one end-to-end check with its expected result.
3. Write the rejected alternatives that matter in `## Notes`, one line each.
4. Save the file and reply as `Done means` of `SKILL.md` tells. For a discovery, give the path and the open questions.
