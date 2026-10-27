---
name: oc-doc-design
description: "Design docs that reduce cognitive load. Trigger: writing guides, READMEs, RFCs, onboarding, architecture, or review-facing docs."
license: Apache-2.0
metadata:
  author: gentleman-programming
  adapted_by: andresnator
  source: gentleman-programming/gentle-ai
  status: testing
  version: "2.1.0"
---
# Documentation design

## Intent

- **Goal:** Low-cognitive-load docs people understand quickly, retain, and use in review.
- **Limits:** Prefer the repository's own template when it is stronger than the default shape below.
- **Fails if:** any Quality needs pattern is violated or the PR scenario is unmet.

## Context

- **Reads:** The doc, repository templates, and for PRs the changed files and line counts.
- **Never reads:** none.
- **Persona:** Documentation designer with review empathy.
- **Scope:** Frontmatter triggers, plus PR descriptions, review notes, workflow docs, and any doc that is dense or hard to scan.

## Expectations

- **Scenarios:**
  - WHEN documenting a PR THEN state what to review first and what is out of scope, link previous and next PR when chained, keep one decision or unit per section, and use checklists for acceptance and verification.
- **Done means:** the doc applies the patterns below.
- **Quality needs:**

  | Pattern | Rule |
  |---------|------|
  | Lead with the answer | Decision, action, or outcome first; context after. |
  | Progressive disclosure | Happy path first, then details, edge cases, references. |
  | Chunking | Small related sections; short flat lists. |
  | Signposting | Headings, labels, callouts, summaries show where readers are. |
  | Recognition over recall | Tables, checklists, examples, templates over remembered prose. |
  | Review empathy | Design docs so reviewers can verify intent without reconstructing the whole story. |

## Method

### Default shape

```markdown
# <Outcome-oriented title>

<One paragraph: what changed, who it helps, and why it matters.>

## Quick path

1. <First action>
2. <Second action>
3. <Verification or expected result>

## Details

| Topic | Decision |
|-------|----------|
| <area> | <concise explanation> |

## Checklist

- [ ] <Reader can confirm this>
- [ ] <Reader can confirm that>

## Next step

<Link or action that continues the workflow.>
```

### Commands

```bash
# Check markdown files changed in the current branch
git diff --name-only -- '*.md'

# Inspect PR changed-line count for cognitive load
gh pr view <PR_NUMBER> --json additions,deletions,changedFiles
```
