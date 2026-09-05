---
name: cornell-notes
description: "Trigger: Cornell note, lesson notes, standalone learning summary. Transform supplied material into self-contained Markdown inline."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "3.0.0"
---

# Cornell Notes

## Activation

Format supplied teaching material into an inline Cornell lesson or standalone summary. This is a transformation method, not a publisher or a lesson-closing workflow.

## Inputs

Required: source material and profile (`lesson` or `summary`). Optional: title, supplied date, used sources, language, learner explanation, concept IDs, and already selected card IDs. Default language to the conversation. Distinguish teacher statements from actual learner words; mark missing learner evidence pending.

## Method

For a lesson, use `assets/cornell-template.md`. Write self-contained retrieval questions with explanatory Notes: each expected answer must be available in that row's taught material. Include the central model and relationships. Prefer a small useful set; split an overloaded lesson rather than fill a quota. Questions are available for practice whether or not selected for scheduling.

Keep the learner Summary pending until their own explanation is supplied. Lightly clean their wording without adding understanding they did not demonstrate. Record retention disposition and only supplied selected IDs, including an empty list. Never infer consent from cues, a Summary, or a note.

For a summary, lead with a synthesis, then a question/Notes table, a session-grounded example when available, and sources actually used (or the localized equivalent of `None`). Translate headings into the requested language. Do not add route metadata, progress, retention, or an invented learner Summary.

A diagram is optional when it clarifies the material. Do not invent citations or claim that formatting improves measured comprehension.

## Output

Return the complete Markdown inline, distinguishing teacher synthesis from learner evidence. No scheduling, sibling invocation, directory discovery, or file write. Optional persistence belongs to the caller with an explicit destination and save request.
