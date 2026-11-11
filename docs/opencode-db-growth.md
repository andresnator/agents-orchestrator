# Manage OpenCode Database Growth

OpenCode stores sessions in one SQLite database and does not prune it. Long streamed sessions make the file large. This repository does not edit the database.

## Quick inspection

Print the exact path and the current file size:

```bash
opencode db path
ls -lh "$(opencode db path)"
```

List the sessions by title and date:

```bash
opencode session list
```

## Delete one session safely

1. Stop each OpenCode TUI and `serve` process that uses the database.
2. Find the session id with `opencode session list`.
3. Export the data that you want to keep.
4. Delete the session with the supported session command.
5. Restart OpenCode.
6. Examine the session list and the file size.

```bash
opencode export <sessionID> > session.json
opencode session delete <sessionID>
opencode session list
ls -lh "$(opencode db path)"
```

If the export can leave the local computer, use `opencode export --sanitize <sessionID>`.

Deletion also removes child sessions. There is no bulk prune command. Repeat the workflow for each session. Do not change the database tables directly.

## Cautions

- Data loss can occur because deletion is permanent. If you are not sure, export first.
- Titles are not unique. Verify the exact session id.
- Exports can contain prompts, tool output, and file data. Store them safely.
