---
name: oc-retro
description: "Retrospective on a session: ranked changes to the harness so the next run is better. Trigger: retro, retrospectiva, retrospective, /retro."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: andresnator
  source: https://github.com/mattpocock/skills
  version: "1.0.1"
  status: testing
---

# Retro

## Intent

- **Goal:** Find where one session lost time, tokens, or user attention. Propose changes to the environment of the agent that prevent it in the next run.
- **Limits:** Report only. Do not edit the harness, the project, or Git. The one write is the report file under `.ai/retro/`.
- **Fails if:** a candidate has no evidence from the session; a candidate blames the model and names no file to change. The report has more than seven candidates.

## Context

- **Reads:** the session; the plan file and its `## Deviations` and `- [!]` tasks; `.ai/factory/board.md` and `.ai/factory/logs/`. Also: the harness files that the session used (skills, agents, commands, the global `AGENTS.md`); the check commands of the project.
- **Scope:** `/retro`, or a request for a retrospective. The default session is the current conversation. For a different session, use the export file or the session id that the user gives.

## Expectations

- **Scenarios:**
  - WHEN the session has no problem that a file change can prevent THEN say so in one line. Do not invent candidates.
  - WHEN the user gives a focus (for example `factory`) THEN examine only that part.
- **Done means:** the report is in chat and in `.ai/retro/<YYYY-MM-DD>-<slug>.md`, with the candidates in order of cost to the user, most expensive first.

## Method

1. Read the session from start to end. List each event of these types: a question to the user, a stop, a retry, a wrong route or skill. Also list: a search that took many steps, a failed check, a correction from the user.
2. For each event, find the cause in the environment. Use the categories below.
3. Keep the events that a file change can prevent. Join events with the same cause.
4. Write one candidate for each cause. Select the cheapest fix that works. Use this order: a script or automated check, a change to one skill or command, a rule in the global `AGENTS.md`.
5. Save the report. Show it in chat.

### Categories

| Category | Question |
| --- | --- |
| Stops and questions | Did the agent ask or stop when it could assume, note, and continue? Which sentence caused it? |
| Routing | Did the agent load the wrong skill, or no skill? Does a `description` need a trigger, or do two descriptions compete? |
| Navigation | Did the agent use many steps to find a file or a fact? Would one pointer line prevent that? |
| Automated checks | Could a test, a linter, or a hook find the error that the agent made? Does the check exist but not run? |
| Review rules | Did the review miss an error? Add the rule to the judge brief or the standards, not to the implementation rules. |
| Token economy | Did a tool call, a file read, or a skill load cost many tokens for a small result? |
| No-ops | Which instruction that was in context did not change the behavior? Propose to delete it. |
| Information access | Which fact did the agent need and not have? For example a log, a version, a doc. |
| Factory | Did a task end as `needs-input`, `failed`, or `conflict`? Was the cause the brief, the split of the tasks, or the script? |

A rule in the global `AGENTS.md` costs tokens in each session. Propose one only when no script, check, or skill can do the work.

### Report format

```markdown
# Retro: <session topic>

Session: <current | id | file> · <date>

## 1. <problem in one line>

- Evidence: <quote or tool call from the session>
- Cause: <category> — <file and sentence, or the missing piece>
- Change: <exact edit, new check, or deletion>
- Where: <path in the harness or in the project>

## Worked well

- <one to three things to keep, with the file that caused them>
```

Give paths in the harness relative to its root, for example `skills/oc-build/SKILL.md`. Give paths in the project relative to the project root.

## Attribution

Adapted from the `retro` skill by Matt Pocock at <https://github.com/mattpocock/skills>.
