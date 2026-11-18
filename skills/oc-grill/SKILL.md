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
- **Limits:** Planning only. Keep code, tests, and build files unchanged. Write only domain notes (docs mode) or the plan file (plan mode).
- **Fails if:** the user is asked something the repository can answer; plan mode ends without a saved plan.

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
  - WHEN the mode is docs THEN load `oc-domain` and write the notes that the user confirmed in the interview.
  - WHEN the user stops the interview early in plan mode THEN write the plan with the open points as assumptions in `## Notes`.
- **Done means:** the reply gives the current question or the conclusion. At the end it gives the file path, if a file was written, and the open decisions. Plan mode also gives `ejecuta el plan <path>`.
- **Quality needs:** talk in the language of the user. Write files in English.

## Method

The user asked for an interview, so questions are the work here. Follow `references/interview.md` in all modes.

Plan mode:

1. Interview until these are clear: the goal, the checks that show it is done, the task groups with their files, and the main risks.
2. Load `oc-plan` and use its "Plan format" and `assets/plan-template.md`.
3. Save the plan to `.ai/plans/<slug>.md`. Make the slug from the goal. If the path exists already, add a numeric suffix (`-2`).
4. Put decisions from the interview in `## Notes`.

## Attribution

Inspired by Matt Pocock's interview skills at <https://github.com/mattpocock/skills>.
