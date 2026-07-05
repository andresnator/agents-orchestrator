# OpenCode Overrides

Put frontmatter-only override files in `agents/` or `commands/` when OpenCode needs metadata that should not live in the portable catalog.

Example:

```markdown
---
model: opencode/specific-model
temperature: 0.2
---
```

The merge is shallow by top-level key. If an override defines `permission`, it replaces the catalog `permission` block for the OpenCode build.
