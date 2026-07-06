# Skills

This directory is the source of truth for reusable skill bodies.

Each skill lives at:

```text
skills/<skill>/SKILL.md
```

Domains declare skill usage with relative symlinks:

```text
domains/<domain>/skills/<skill> -> ../../../skills/<skill>
```

Edit skill content only under `skills/`. Add or remove domain symlinks to change which domains install or advertise a skill.
