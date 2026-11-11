# Docs Domain

This domain makes product documents, decisions, Jira artifacts, summaries, presentations, and transcriptions.

## Quick path

1. Include `docs` in the installer domains.
2. Start with `/doc`, or ask for a PRD or an ADR.
3. Review the artifact before you publish it.

## Entry points

| Entry | Use | Result |
|---|---|---|
| `/doc` | Route general documentation work | Most specific documentation skill |

A PRD request activates `oc-prd`. An ADR request activates `oc-adr`. The selected skill owns its workflow and output.

## Components

Unmarked rows are skills.

| Name | Purpose |
|---|---|
| `/doc` | Routes general documentation work |
| `oc-adr` | Documents decisions and trade-offs |
| `oc-issue` | Creates agent-ready implementation issues |
| `oc-doc-design` | Reduces documentation cognitive load |
| `oc-jira` | Creates Jira Tasks, Stories, and Spikes |
| `oc-prd` | Creates full or light PRDs |
| `oc-rfc` | Creates technical proposals |
| `oc-slides` | Builds verified retro Slidev decks |
| `oc-summarize` | Synthesizes book chapters pedagogically |
| `oc-usm` | Creates journey-first MVP story maps |
| `oc-whisper` | Transcribes and summarizes media |
