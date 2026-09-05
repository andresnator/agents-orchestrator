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

1. Ground the mission in something the learner will demonstrably do. Infer only supported context; propose effort and cadence for correction. Organize modules by prerequisite, each with one tangible win. Confirm the proposed scope before teaching it.
2. **Class:** explain the objective, central relationships, and a distinct worked example. Ask one focused question at a time in normal chat. Clarify without solving the learner's target task.
3. After teaching, propose zero to two fundamental recall previews when eligible concepts exist. Show the exact cue, expected answer, and reason. Selection, edit, save-none, and postponement are valid. This retention decision never implies readiness for Practice.
4. **Practice:** wait for a later learner readiness response. Set a new application, give one hint at a time, and fade help according to observed performance. Record actual attempts as pending, partial, stuck, or done. Inspect supplied repository evidence only to teach or assess; never modify or solve learner work.
5. **Consolidation:** reuse the learner's real causal explanation and transfer evidence when they meet the rubric. Otherwise ask for their explanation, affirm correct parts, explain the specific gap, and invite a revision. Do not invent a Summary or demand redundant debrief/teach-back rituals. Probe foundational uncertainty selectively.
6. **Close:** require completed practice, learner explanation of essential decisions, no blocking conceptual gaps, and resolved retention (`selected`, `none`, or `deferred`). Selected references may be empty. Topic completion additionally requires practical capstone evidence and explanation against every mission criterion. Confidence alone proves neither mastery nor retention.

Use stable IDs for the mission's distinct concepts and prerequisites. Nominate reusable prerequisites, decision rules, and costly recurring misconceptions, with one rationale each. The default fundamental shortlist is at most `floor(concept_count / 5)`; never pad the denominator. Fewer than five concepts can mean zero. Explicit learner exceptions must name the shown concept; untaught concepts remain ineligible.

Clarification may expand Class or unfinished Practice within its win. After practice is done, place new concepts in separate reinforcement; preserve the practiced scope. A restart or worker notification never advances a phase.

## Output

Return the current teaching step, actual evidence and unresolved gaps, proposed progress, retention proposals/disposition, and the next learner action inline. Distinguish proposals from committed state. Use the learner's materials language, defaulting to conversation language; diagrams are purposeful and optional. No sibling calls, project discovery, or implicit writes.
