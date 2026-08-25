# Docs Domain

Product documents, technical decisions, Jira artifacts, summaries, presentations, and transcription. The domain uses shared interview and question skills from `common`.

## Quick path

1. Include `docs,common` in the selected installer domains.
2. Start with `/doc`, `/prd`, or `/adr`.
3. Review the selected skill's artifact before publishing it externally.

## Entry points

| Entry | Use | Result |
|---|---|---|
| `/doc` | Route general documentation work | Most specific documentation skill |
| `/prd` | Choose requirements depth | Full or lightweight PRD workflow |
| `/adr` | Record a technical decision | Architecture Decision Record |

The selected skill owns its workflow and output. Commands do not duplicate or override skill contracts.

## Components

| Type | Name | Purpose |
|---|---|---|
| Command | `/adr` | Creates technical decision ADRs |
| Command | `/doc` | Routes general documentation work |
| Command | `/prd` | Selects appropriate PRD depth |
| Skill | `adr` | Documents decisions and trade-offs |
| Skill | `buildable-issue` | Creates agent-ready implementation issues |
| Skill | `cognitive-doc-design` | Reduces documentation cognitive load |
| Skill | `jira-spike` | Creates research-ready Jira Spikes |
| Skill | `jira-task` | Creates developer-ready Jira Tasks |
| Skill | `jira-user-story` | Creates developer-ready User Stories |
| Skill | `prd` | Creates rigorous high-stakes PRDs |
| Skill | `prd-light` | Creates lightweight MVP PRDs |
| Skill | `rfc` | Creates technical proposals with trade-offs |
| Skill | `slidev-retro-deck` | Builds verified retro Slidev decks |
| Skill | `summarize` | Synthesizes book chapters pedagogically |
| Skill | `usm` | Creates journey-first MVP story maps |
| Skill | `whisper-extract` | Transcribes and summarizes media |
