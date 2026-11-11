# Skills

This directory owns only skill bodies that two or more domains share.

```text
domains/<domain>/skills/<skill>/SKILL.md                    # exclusive skill
skills/<skill>/SKILL.md                                     # shared body
domains/<domain>/skills/<skill> -> ../../../skills/<skill>  # symlink per owner
```

Never copy a body. When a second domain owns a skill, move the body here and add the symlinks in the same change. When one owner remains, move the body back into that domain.
