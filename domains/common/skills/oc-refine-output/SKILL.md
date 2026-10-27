---
name: oc-refine-output
description: "Trigger: refine output, summarize output, compact logs, reduce cognitive load, remove duplicates. Refines heavy textual output into a concise, faithful, non-duplicative version."
license: MIT
metadata:
  author: andresnator
  status: in-progress
  version: "3.1.0"
---

# Cognitive Output Refiner

## Intent

- **Goal:** Turn heavy textual output into a concise, faithful, non-duplicative, easier-to-scan version.
- **Limits:**
  - Redaction takes precedence over all exact-preservation requirements, including the output template. Never include credential material (secrets, credentials, inline credentials, connection strings, URL-embedded credentials, API keys, access tokens, cookies, passwords, private keys, session identifiers, authorization headers) in whole or in part; replace the full value with a placeholder such as `[REDACTED_TOKEN]`. When an ID's sensitivity is ambiguous, redact it.
  - Preserve the input language; do not translate unless asked.
  - Never overwrite source content; produce a separate response or file.
- **Fails if:** an inference is presented as input fact (label it `Inference`, `Likely cause`, or `Possible next step`); useful diagnostic detail is lost; meaningful differences between duplicates disappear; credential material or ambiguous sensitive identifiers appear.

## Context

- **Reads:** the user-supplied output: Markdown, console output, logs, test results, or agent responses.
- **Never reads:** none beyond the input.
- **Persona:** faithful editor reducing cognitive load.
- **Scope:** only when the user explicitly asks in English to refine, summarize, compact, deduplicate, or reduce cognitive load. Do not activate just because output is long.

## Expectations

- **Scenarios:**
  - WHEN input is already concise THEN say no refinement is needed and offer at most a micro-improvement.
  - WHEN the user asks to save/create a document or provides a file as input THEN write `{topic_snake_case}_v<semver>.md` in the current working directory unless a path is given; infer the topic, asking only if unclear; do not save the original; start at `v1.0.0` when no prior refined version exists. SemVer: patch for clarity/order/deduplication, minor for added information or structure changes, major for changed interpretation.
  - WHEN the user is not satisfied THEN ask one correction question at a time in normal chat (`[Direct question]`, then `Recommendation: ...` only when useful; no headings, numbering, rationale blocks, or interview-length estimates; the `question` tool only for closed confirmations or enumerated choices), then generate a new complete version, not a patch.
- **Done means:** the output contract below, with every Satisfaction Check item honestly true before rendering (fix the output first if one fails).
- **Quality needs:** target 30–50% of original size; 10–20% only for explicit ultra-compact requests. Fidelity beats size. Keep errors, relevant stack frames, commands, paths, public/non-sensitive IDs, decisions, trade-offs, critical warnings, verification steps, and next steps, redacting usernames, local/private path prefixes, internal hostnames, and credentials while keeping filenames, function names, line numbers, error codes, and public IDs. Deduplicate to one canonical version.

## Method

| Input | Strategy |
|---|---|
| Markdown/docs | Preserve useful hierarchy, improve headings, merge duplicated sections. |
| Console/logs/tests | Group by signal: result, errors, warnings, files, commands, next steps. Preserve order only when causal. |
| Agent/LLM output | Remove repetition, separate decisions from explanations, cut unnecessary narrative. |

Output contract (omit optional `Preserved Details`, `Information Loss`, `Compression Notes` when empty):

```md
## TL;DR
- <2-4 bullets with the essential signal>

## Refined Output
<clean, grouped, non-duplicative output>

## Preserved Details
<errors, redacted commands/paths, public/non-sensitive IDs, decisions, redacted placeholders, or other must-preserve facts; never include credential material or ambiguous sensitive identifiers>

## Information Loss
<Low/Medium/High only when compression risk exists>

## Compression Notes
<meaningful removals, merges, or heading changes>

## Satisfaction Check
- [ ] Preserves the important facts.
- [ ] Removes duplicated/noisy content.
- [ ] Is easier to scan.
- [ ] Does not invent conclusions.
- [ ] Fully replaces credential material and redacts sensitive identifiers before rendering.

Are you satisfied with this refined version?
```

Example: headings `Error Details` and `More Error Details` repeating the same failing test become one `### Test Failure` section, with the merge noted in `Compression Notes`.
