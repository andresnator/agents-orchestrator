---
name: oc-grill
description: "Trigger: grill me, grill with docs, grill me plan, entrevistame, interview me. Interviews one question at a time to stress-test a plan or design."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: andresnator
  source: https://github.com/mattpocock/skills
  status: testing
  version: "10.0.0"
---

# Grill

## Intent

- **Goal:** A clear decision, domain notes, or one saved plan, reached through one question at a time.
- **Limits:** Planning only. Keep code, tests, and build files unchanged. Plain mode writes no file. Docs mode writes only the domain glossary (`CONTEXT.md`) and an ADR that the user accepted. Plan mode writes only the plan file.
- **Fails if:**
  - the user is asked something the repository can answer;
  - docs mode writes a term or an ADR that the user did not confirm in an answer;
  - plan mode ends without a saved plan.

## Context

- **Reads:** the answers of the user; repository facts; `references/interview.md`; `oc-domain` in docs mode; `oc-plan` in plan mode.
- **Scope:**

  | Trigger | Mode | Result |
  | --- | --- | --- |
  | `grill me`, `grill code`, `entrevistame`, `interview me` | plain | A decision reached by interview. |
  | `grill with docs`, `grill docs open` | docs | The interview, plus domain notes. |
  | `grill me plan`, `entrevistame plan` (old alias: `sdd`) | plan | One plan at `.ai/plans/<slug>.md`. |

## Expectations

- **Scenarios:**
  - WHEN the mode is docs THEN load `oc-domain`. Write a term to the glossary only after the user confirmed its definition in an answer. List the other terms in the reply as open.
  - WHEN a decision in docs mode qualifies for an ADR THEN offer it, and write the ADR only if the user accepts.
  - WHEN the user stops the interview early in plan mode THEN write the plan with the open points as assumptions in `## Notes`.
- **Done means:** the reply gives the current question or the conclusion. At the end it gives the file path, if a file was written, and the open decisions. Plan mode also gives `ejecuta el plan <path>`.
- **Quality needs:** talk in the language of the user. Write files in English.

## Method

The user asked for an interview, so questions are the work here. Follow `references/interview.md` in all modes.

Plan mode:

1. Interview until these are clear: the goal, the checks that show it is done, the scope, and the main risks. Find the files and the task groups in the repository yourself.
2. Load `oc-plan` and write the plan as its "Plan format" tells. Do not ask for approval before you save it.
3. Put the decisions from the interview in `## Notes`.

## Attribution

Inspired by Matt Pocock's interview skills at <https://github.com/mattpocock/skills>.
