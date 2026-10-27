# Fix brief

Brief for the `general` subagent that loads `oc-judge-fix`.

```text
Load skill oc-judge-fix.
Target: <exact scope>
Findings: <confirmed or emphasis-confirmed rows only>
Rules: <0-5 distilled project rules>

Apply one minimal fix per listed id. Touch nothing else. Run the named check after each fix. Do not commit or push.

OK fix files=<csv> check=<one-line>
OPEN <id> <reason>
```
