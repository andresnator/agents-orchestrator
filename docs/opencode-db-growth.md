# OpenCode database growth

OpenCode keeps every session, message, part, and event in one SQLite file at
`~/.local/share/opencode/opencode.db` (`opencode db path` prints the exact location). Nothing
prunes it. It is runtime state, never a repository artifact, so this repository ships **no
script that touches it** — the recipes below are run by hand, by you, with OpenCode stopped.

## What grows

Measured on 2026-07-30 against a database holding a single month of sessions (oldest session
2026-06-30), 1.02 GiB total:

| Object | Size | Rows |
|---|---|---|
| `event` table | 628 MB | 260,536 |
| `part` table | 278 MB | 76,256 |
| `session_message` table | 40 MB | — |
| `event` indexes (3) | 47 MB | — |
| `message` table | 11 MB | 15,253 |
| `session` table | <1 MB | 1,287 |

The event log is the whole story, and one event type is two thirds of it:

| Event type | Count | Size |
|---|---|---|
| `message.part.updated.1` | 165,984 | 422 MB |
| `message.updated.1` | 56,746 | 72 MB |
| `session.next.tool.success.1` | 3,115 | 32 MB |
| `session.updated.1` | 17,568 | 13 MB |

**Why that one type dominates.** A part — an assistant text block, a reasoning block, a tool
result — is re-persisted *in full* on every stream delta, as a fresh event row carrying a
complete snapshot. A part that streams to 1 MB (the largest one here is 1.11 MB) is written
out once per delta, so its cost is quadratic in its final length, and the whole growth curve
of the part lands in the event log. Long turns produce long parts: the same high-context turns
that make the orchestrator feel slow are what fills this table. Keeping agents' context small
(see [delegation receipts](delegation-receipts.md)) shrinks this file as a side effect.

## Inspecting it

`opencode db` opens a shell or runs one query against the live database:

```bash
opencode db "select count(*) as sessions from session"
opencode db "select type, count(*) as n, sum(length(data)) as bytes from event group by type order by bytes desc limit 5"
```

Per-object sizes come from the `dbstat` virtual table:

```bash
opencode db "select name, round(sum(pgsize)/1048576.0, 1) as mb from dbstat group by name order by sum(pgsize) desc limit 12"
```

## Pruning one session

`opencode session delete <sessionID>` is the supported path, and it is complete: verified on a
snapshot, deleting one session removed its 5,181 events, 369 parts, 77 messages, and its
`event_sequence` row — plus its two child sessions (subagent sessions hang off `parent_id`).

```bash
opencode session list                 # pick by title and date
opencode export <sessionID> > session.json   # only if you may want it back
opencode session delete <sessionID>
```

## Pruning by age in bulk

For hundreds of sessions, one CLI invocation each is too slow; SQL does it in under a second.
The cascade needs two deletes, because events hang off `event_sequence` (by `aggregate_id`,
which is the session id) rather than off `session`:

**Stop OpenCode first** — every running instance, TUI and `serve` — then:

```bash
DB=$(opencode db path)

# 1. Back up. Use .backup, not cp: the database is in WAL mode, so a plain copy of the
#    .db file without its -wal sibling is a torn snapshot.
sqlite3 "file:$DB?mode=ro" ".backup '$HOME/opencode-db-backup-$(date +%Y%m%d).db'"

# 2. Prune. SQLite ignores ON DELETE CASCADE unless foreign keys are enabled for the
#    connection — without this pragma you get orphaned parts and messages, not a prune.
sqlite3 "$DB" <<'SQL'
PRAGMA foreign_keys=ON;
BEGIN;
DELETE FROM session WHERE time_updated < (strftime('%s','now') - 14*86400)*1000;
DELETE FROM event_sequence WHERE aggregate_id NOT IN (SELECT id FROM session);
COMMIT;
SQL

# 3. Reclaim the disk. DELETE only frees pages inside the file; the file itself shrinks
#    only on VACUUM, which needs free space roughly equal to the current database size.
sqlite3 "$DB" "VACUUM;"

# 4. Confirm.
sqlite3 "file:$DB?mode=ro" "PRAGMA integrity_check; PRAGMA foreign_key_check;"
```

Measured result of exactly that run at a 14-day cut, on the 1.02 GiB snapshot above:

| | Before | After |
|---|---|---|
| Sessions | 1,287 | 257 |
| Events | 260,536 | 94,993 |
| Parts | 76,256 | 30,734 |
| Messages | 15,253 | 4,971 |
| File size | 1,072 MB | 381 MB |

The delete took 0.7 s and the vacuum 0.9 s. `integrity_check` and `foreign_key_check` both
came back clean, and `opencode session list` read the pruned database normally.

## Cautions

- Deleting a session is irreversible and takes its whole transcript with it. `opencode export
  <sessionID>` first for anything you might want to read again.
- Run this with OpenCode stopped. SQLite will refuse or block on a locked database, and a
  `VACUUM` racing a live writer is not worth finding out about.
- The age cut is `session.time_updated`, in **milliseconds** — the `*1000` in the expression
  above is not decoration.
- Child (subagent) sessions carry their own `time_updated`. A parent older than the cut whose
  subagent session is newer leaves that child behind as an orphan row; it is harmless and the
  next cut collects it.
