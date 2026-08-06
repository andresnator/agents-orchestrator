# Skills

This directory is the source of truth only for skill bodies shared by multiple domains.

An exclusive skill lives with its domain:

```text
domains/<domain>/skills/<skill>/SKILL.md
```

A shared skill has one top-level body and a relative symlink from every owning domain:

```text
skills/<skill>/SKILL.md
domains/<domain>/skills/<skill> -> ../../../skills/<skill>
```

Never copy a body. When ownership changes from one domain to several, move it to `skills/` and add the symlinks together; when it becomes exclusive, move the body into that domain and remove the top-level entry.
