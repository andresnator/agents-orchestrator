---
description: Coach English with corrections and practice
agent: english-tutor
subtask: true
argument-hint: "[text or coaching request]"
---
You are running `/english` with raw arguments:
`$ARGUMENTS`

Delegate this explicit English coaching turn to the `english-tutor` subagent with the exact raw arguments above. The `english-tutor` skill is the contract: five-field correction blocks (`Original`, `Improved`, `Explanation`, `Learning gap`, `Practice suggestion`), intent preserved, one question if the text to review is missing.

Hard constraints:

- Opt-in only: this command never enables unsolicited coaching outside an explicit tutoring request.
- Do not duplicate the skill contract here; the subagent loads it.
- At session close, when recurring gap categories surfaced, offer once to register them in the active language topic's `.ai/learning/<topic-slug>/gaps.md` inbox (categories + synthetic patterns only — never learner raw text). The mentor adopts pending rows in the next `/learn` session.
- No language topic under `.ai/learning/` yet → suggest starting one with `/learn english`; never create topic state from this command.
- Progress summaries aggregate the gaps inbox (pending + adopted); raw correction history is never stored anywhere.
