# Docs Domain

Product documents, technical decisions, Jira artifacts, summaries, presentations, and transcription. Interviews happen in normal chat; final artifact formats remain unchanged.

## Quick path

1. Include `docs` in the selected installer domains.
2. Start with `/doc`, or ask for a PRD or ADR directly.
3. Review the selected skill's artifact before publishing it externally.

## Entry points

| Entry | Use | Result |
|---|---|---|
| `/doc` | Route general documentation work | Most specific documentation skill |

PRD and ADR requests activate `oc-prd` and `oc-adr` directly. The selected skill owns its workflow and output. Commands do not duplicate or override skill contracts.

After changing this domain, run the affected [Docs manual tests](manual-tests.md).

## Components

| Type | Name | Purpose |
|---|---|---|
| Command | `/doc` | Routes general documentation work |
| Skill | `oc-adr` | Documents decisions and trade-offs |
| Skill | `oc-issue` | Creates agent-ready implementation issues |
| Skill | `oc-doc-design` | Reduces documentation cognitive load |
| Skill | `oc-jira` | Creates Jira Tasks, Stories, and Spikes |
| Skill | `oc-prd` | Creates full or light PRDs |
| Skill | `oc-rfc` | Creates technical proposals with trade-offs |
| Skill | `oc-slides` | Builds verified retro Slidev decks |
| Skill | `oc-summarize` | Synthesizes book chapters pedagogically |
| Skill | `oc-usm` | Creates journey-first MVP story maps |
| Skill | `oc-whisper` | Transcribes and summarizes media |
