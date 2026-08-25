# Manage OpenCode Database Growth

OpenCode stores sessions, messages, parts, and events in one SQLite database. It does not currently prune them automatically, so long streaming sessions can make the file large.

The database is runtime state, never a repository artifact. This repository ships no cleanup script and does not edit it.

## Quick inspection

Print the exact path and current file size:

```bash
opencode db path
ls -lh "$(opencode db path)"
```

List sessions by title and date:

```bash
opencode session list
```

Large growth usually comes from event snapshots written during long streamed turns. Smaller agent contexts and compact A2A returns reduce future growth, but do not remove existing data.

## Delete one session safely

1. Stop every OpenCode TUI and `serve` process using the database.
2. Find the session id with `opencode session list`.
3. Export anything worth keeping.
4. Delete through the supported session command.
5. Restart OpenCode and confirm the session list and file size.

```bash
opencode export <sessionID> > session.json
opencode session delete <sessionID>
opencode session list
ls -lh "$(opencode db path)"
```

Exports may contain prompts, tool output, and file data. Use `opencode export --sanitize <sessionID>` when the archive may leave the local machine.

Session deletion also removes owned child-session data through OpenCode's supported lifecycle. There is no supported bulk age-prune command; repeat the CLI workflow for selected sessions instead of modifying database tables directly.

## Cautions

- Deletion is irreversible. Export first when uncertain.
- Stop OpenCode before cleanup to avoid live-writer conflicts.
- Verify the exact session id; titles are not unique.
- Store or delete exported JSON according to its sensitivity.
