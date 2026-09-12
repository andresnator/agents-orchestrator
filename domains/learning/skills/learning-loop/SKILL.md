---
name: learning-loop
description: "Trigger: /learn path, learning route, path step, progress. Independent mission-grounded Class, Practice, and Consolidation from explicit learner evidence."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: andresnator
  source: https://github.com/mattpocock/skills
  status: testing
  version: "4.0.0"
---

# Learning Loop

## Activation

Conduct a mission-grounded learning path step, including explicit `/learn path` requests. This method owns teaching progression; a caller owns routing, persistence, dates, and task lifecycle.

## Inputs

Required: goal and visible learner level (unknown is valid). Optional: prior progress snapshot, actual learner work, verified source material, concept inventory, materials language, and cadence. With no snapshot, propose a small path inline; never discover one from files. Use only this directory's optional assets.

## Method

1. Ground the mission in an observable outcome: an explanation, decision, or practical result according to the agreed scope. Infer only supported context; propose effort and cadence for correction. Organize modules by prerequisite, each with one tangible win. Confirm the proposed scope before teaching it.
2. **Class:** explain the objective, central relationships, and a distinct worked example. Ask one focused question at a time in normal chat. Clarify without solving the learner's target task.
3. **Practice (optional):** offer Practicar / Omitir once immediately after Class. Reuse a recorded choice on resume; clarification or dismissal never advances the phase. If omitted from unfinished Practice, preserve actual attempts and move to a brief Consolidation without inventing completed practice. If accepted, set a new application, give one hint at a time, and fade help according to observed performance. Record actual attempts as pending, partial, stuck, or done. Inspect supplied repository evidence only to teach or assess; never modify or solve learner work.
5. **Consolidation:** reuse the learner's real causal explanation and transfer evidence when they meet the rubric. Otherwise ask for their explanation, affirm correct parts, explain the specific gap, and invite a revision. Do not invent a Summary or demand redundant debrief/teach-back rituals. Probe foundational uncertainty selectively.
6. **Close:** require completed or explicitly omitted practice, learner explanation of essential decisions, no blocking conceptual gaps, and current note and exercise materials. Topic completion requires real evidence against the agreed mission criteria; no practical capstone is mandatory by default. Skipping exercises does not demonstrate practical competence.

Use stable IDs for the mission's distinct concepts and prerequisites. Keep prerequisites, decision rules, and recurring misconceptions available as optional practice prompts.

Clarification may expand Class or unfinished Practice within its win. After practice is done, place new concepts in separate reinforcement unless the learner explicitly revises the mission; preserve evidence of the practiced scope. A restart or worker result never advances a phase. Generate the note and exercise even when practice is skipped; record omission in existing evidence/status fields and preserve the current paths, sections, columns, and templates. Explicit exercise requests and language input-only/production criteria retain their scope.

## Adaptation

- When the learner changes the goal, propose the revised mission and affected module wins together, including downstream requirements. The caller obtains consent and persists the revision. Reassess existing evidence; distinguish retired requirements from resolved gaps and demonstrated competence.
- When prior explanations already cover the goal, reuse them. With explicit omission, assess Consolidation without inventing an attempt or practical mastery. Refresh materials before closure.
- When the learner needs another module now, propose deferring the current module and selecting the requested one through the caller. Preserve its phase, attempts, gaps and requirements; materials and closure are not prerequisites for navigation. Explain relevant dependencies briefly and respect the learner's choice. Resume the selected module, not automatically the first unfinished one.

## Output

Return the current teaching step, actual evidence and unresolved gaps, proposed progress, and the next learner action inline. Distinguish teacher assessment from literal learner evidence. Use the learner's materials language, defaulting to conversation language; diagrams are purposeful and optional. No sibling calls, project discovery, or implicit writes.

## Exercise template

When an exercise artifact is requested, use this complete template. It is kept identical to `assets/exercise-template.md` so a writer can compose it without reading another file.

```markdown
# Exercise — {Name}

> Module: {ID or standalone} · Date: {supplied date or unknown}
> Where: {supplied repository scope or self-contained task}

## Brief

{One new application with a tangible win, distinct from the worked example.}

## Constraints and rubric

- {scope constraint}
- {observable criterion}

## Hints

{Reveal one hint at a time on request. Never include the complete solution.}

## Outcome

- Attempt: pending
- Result: pending
- Learner evidence: pending
- Consolidation: pending; reuse qualifying explanation/transfer evidence
- Blocking gaps: not assessed
```
