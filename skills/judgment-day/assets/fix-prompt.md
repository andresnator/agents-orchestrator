# Fix brief

Fallback when `jd-fix` is unavailable.

```text
Target: <exact scope>
Authorization: <explicit fix instruction; exact scope and eligible ids>
Receipt: <current content SHA-256 matching the authorized target>
Findings: <authorized confirmed or emphasis-confirmed rows only>
Rules: <0-5 distilled project rules>

Check the receipt before editing; stop on stale inputs. Apply one minimal fix per authorized id. Touch nothing else. Run the named check after each fix. Do not commit or push.

OK fix files=<csv> check=<one-line>
OPEN <id> <reason>
```
