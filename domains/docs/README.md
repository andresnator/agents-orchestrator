# Docs Domain

Product documents, technical decisions, Jira artifacts, summaries, presentations, and transcription. Interviews happen in normal chat; final artifact formats remain unchanged.

## Quick path

1. Include `docs` in the selected installer domains.
2. Start with `/doc`, `/prd`, or `/adr`.
3. Review the selected skill's artifact before publishing it externally.

## Entry points

| Entry | Use | Result |
|---|---|---|
| `/doc` | Route general documentation work | Most specific documentation skill |
| `/prd` | Choose requirements depth | Full or lightweight PRD workflow |
| `/adr` | Record a technical decision | Architecture Decision Record |

The selected skill owns its workflow and output. Commands do not duplicate or override skill contracts.

After changing this domain, run the affected [Docs manual tests](manual-tests.md).

## Components

| Type | Name | Purpose |
|---|---|---|
| Command | `/adr` | Creates technical decision ADRs |
| Command | `/doc` | Routes general documentation work |
| Command | `/prd` | Selects appropriate PRD depth |
| Skill | `oc-adr` | Documents decisions and trade-offs |
| Skill | `oc-issue` | Creates agent-ready implementation issues |
| Skill | `oc-doc-design` | Reduces documentation cognitive load |
| Skill | `oc-jira-spike` | Creates research-ready Jira Spikes |
| Skill | `oc-jira-task` | Creates developer-ready Jira Tasks |
| Skill | `oc-jira-story` | Creates developer-ready User Stories |
| Skill | `oc-prd` | Creates rigorous high-stakes PRDs |
| Skill | `oc-prd-light` | Creates lightweight MVP PRDs |
| Skill | `oc-rfc` | Creates technical proposals with trade-offs |
| Skill | `oc-slides` | Builds verified retro Slidev decks |
| Skill | `oc-summarize` | Synthesizes book chapters pedagogically |
| Skill | `oc-usm` | Creates journey-first MVP story maps |
| Skill | `oc-whisper` | Transcribes and summarizes media |
