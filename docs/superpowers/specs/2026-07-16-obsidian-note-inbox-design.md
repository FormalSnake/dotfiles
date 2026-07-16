# Obsidian free-text note inbox — AI filing pipeline — design

Date: 2026-07-16
Host: `macbook` (nix-darwin, always-on host)
Companion to: `2026-07-15-obsidian-livesync-design.md` (the notebook-scan pipeline)

## Goal

A text counterpart to the notebook-scan watcher: one always-at-hand markdown
file in the vault that you type freeform into from any device (mostly mobile).
When you mark a note done, headless Claude reads it with the vault as context
and files it into the right note — creating a project note/structure if it
doesn't exist yet — the same append-only, vault-aware way scans are filed.

Motivating example (raw capture the owner would type): a `BeFit2Sail` block with
an error dump (`err_3`, a tRPC `BAD_GATEWAY`), a stray "voor mezelf" aside, and a
feature note ("live activities and persistent active workouts, confirm to stop").
The agent should recognise these as `BeFit2Sail` project notes, group the bug
report and the feature idea sensibly, and create the `BeFit2Sail` project note if
none exists.

## Decisions (locked, from brainstorming)

- **Inbox file: `~/Notes/Inbox/index.md`** — reuses the existing root `Inbox/`
  folder, one tap on Obsidian mobile. Freeform typing area pinned to the top; a
  running log lives below a sentinel and is owned by the watcher.
- **Trigger: 5-minute poll, gated on the freeform having changed.** launchd
  `StartInterval = 300` + `RunAtLoad`, no `WatchPaths`. Each tick skips
  immediately if the freeform region is unchanged since the last check, so a
  parked draft costs nothing. Rejected: idle-timer auto-file (files notes you
  didn't finish), instant `WatchPaths` on the file (flaky with atomic saves; the
  owner wants the ~5-minute cadence).
- **Done signal: judged by Claude, natural phrasing.** The note is only filed
  when the freeform ends with an "I'm done" phrase the owner can write however
  they like ("done", "that's it", "dat was het", "file this", …). No signal →
  Claude returns `PENDING` and changes nothing. Rejected: a fixed grep phrase
  list (can't honour "say it however you like").
- **Engine: same headless Claude Code as scans** (`claude -p`, `sonnet`, tools
  scoped to the vault, append-only). Rejected: a dumb CanaryLLM call (no vault
  awareness) — same reasoning as the scan pipeline.
- **Structure: its own mixin + script**, parallel to the scan watcher, per the
  repo's one-concern-per-mixin rule — not bolted onto the image script.

## The inbox file

`~/Notes/Inbox/index.md`, created by the vault bootstrap:

```
# Inbox

<!-- watcher log below — do not edit -->
## Log
```

Everything between the `# Inbox` heading and the `<!-- watcher log below … -->`
sentinel is the **freeform region** you type into. Everything from the sentinel
down is the **log**, rewritten by the watcher only. You never edit below the
sentinel.

On a successful file the watcher rewrites the file: the freeform region is
cleared back to blank, and a dated entry is prepended directly under `## Log`
(newest first):

```
# Inbox

<!-- watcher log below — do not edit -->
## Log
### 2026-07-16 14:03 → Projects/BeFit2Sail.md
BeFit2Sail err_3 … live activities, confirm to stop
(a copy of exactly what was filed, for your own record)
```

## Trigger and gating

launchd agent `kyan.obsidian-note-watcher`
(`modules/darwin/mixins/obsidian-note-watcher.nix`, mirroring the scan mixin):
`StartInterval = 300`, `RunAtLoad = true`, `ThrottleInterval = 15`, no
`WatchPaths`. The script path lives in the repo (live-editable without a
rebuild), same pattern as the scan watcher.

Each tick, the script (`scripts/obsidian-note-watcher.sh`):

1. Takes an `mkdir` lock (skip if another run is active).
2. Reads the freeform region (between `# Inbox` and the sentinel).
3. If the freeform is empty → record an empty-state marker and exit.
4. Hashes the freeform region and compares to the hash stored in
   `~/Notes/_inbox/note-watcher.state`. If unchanged → exit (no Claude call).
   Hashing the freeform specifically means the watcher's own log rewrites and
   any LiveSync metadata bumps don't count as "modified".
5. Settle check: sample the file's size, sleep ~2s, sample again; if it changed,
   the file is mid-sync/mid-type — exit and let the next tick retry.
6. Otherwise hand the freeform to Claude (below).
7. Record the current freeform hash on **any** outcome (`FILED`, `PENDING`, or
   `FAILED`) so the note is only re-examined after the owner edits it again —
   no re-check loop on a parked or failing draft.

## The AI call

Same shape as the scan pipeline:

```
cd ~/Notes && claude -p "<prompt>" \
  --model sonnet --max-turns 30 \
  --allowedTools "Read,Glob,Grep,Write,Edit"
```

Prompt instructs the agent to:

1. Treat the supplied text as a raw free-text capture. First decide whether it
   ends with a natural "I'm done / file this" signal. If it does **not**, output
   exactly `PENDING` and change nothing (the owner is still drafting).
2. Otherwise read `Home.md` and search existing notes (`Projects/`, `Startup/`,
   `Meetings/`, `Ideas/`, `Inbox/`) to resolve project names and the owner's
   shorthand.
3. File it: append to the best-matching existing note under a
   `## Note YYYY-MM-DD` heading, or create a new note in the best-fitting folder
   (creating the project note/structure when it's a new project like
   `BeFit2Sail`). Group mixed content sensibly — bug/error reports under a bugs
   section, feature ideas under features. Default to a new `Inbox/` note when
   genuinely unsure.
4. Never delete, rewrite, or reorder existing content — append only. No YAML
   frontmatter. Plain, calm markdown.
5. Last output line MUST be exactly `FILED: <vault-relative note path>` on
   success, or `PENDING` if there was no done signal (writing nothing).

Success detection mirrors the scan script: `rc == 0` **and** a `^FILED:` line in
the captured output. Anything else (`PENDING`, non-zero exit, no marker) is a
no-op for the freeform; `FILED` triggers the clear-and-log rewrite.

## Cost note

While unfiled text without a done signal is parked in the freeform, the first
tick after each edit spends one `sonnet` call to conclude `PENDING`. This is
bounded by the change-gate (only edits trigger a call, not every tick), so a
draft left untouched costs nothing until the owner touches it again.

## Error handling

- **Mid-sync / mid-type file:** settle check (stable size) before reading.
- **Concurrent runs:** `mkdir` lock; a skipped tick retries on the next poll.
- **Agent failure (API error, etc.):** freeform left intact, `FAILED` line in
  `~/Notes/_inbox/note-watcher.log`, hash recorded so it waits for the next edit
  rather than looping. The owner re-triggers by editing the note.
- **File-rewrite vs. a concurrent mobile edit:** the rewrite only happens after a
  done signal (owner has stopped typing); LiveSync's per-document conflict
  resolution covers the small remaining window. The freeform copy is preserved
  in the log entry, so filed text is never lost.
- **Sentinel missing / file hand-mangled:** if the `<!-- watcher log below … -->`
  sentinel isn't found, the whole file is treated as freeform for reading, and
  the rewrite re-establishes the canonical structure on the next successful file.

## What changes in this repo

| Piece | Location |
|---|---|
| Note watcher agent | `modules/darwin/mixins/obsidian-note-watcher.nix` (new launchd agent) |
| Note watcher script | `scripts/obsidian-note-watcher.sh` (new; repo-resident, live-editable) |
| Mixin wiring | import the new mixin in `modules/darwin/default.nix` (beside the scan watcher) |
| Inbox file seed | `Inbox/index.md` added to `scripts/obsidian-vault-bootstrap.sh` |

## Testing / verification

1. Put a couple of lines into `Inbox/index.md` with **no** done signal; wait a
   tick; confirm nothing is filed and `note-watcher.log` shows `PENDING`.
2. Confirm a second tick with the draft unchanged makes **no** Claude call
   (change-gate short-circuits — no new log line).
3. Add a natural done signal; wait a tick; confirm the content lands in the
   right note (a new `Projects/BeFit2Sail.md` for the motivating example, bug and
   feature grouped), the freeform clears, and a dated `## Log` entry appears with
   a copy of the text.
4. Failure test: simulate an agent failure; confirm the freeform is untouched, a
   `FAILED` line is logged, and the note isn't re-examined until edited again.

## Non-goals

- Instant/sub-5-minute filing (`WatchPaths`) — the poll cadence is intentional.
- Preserving text typed *after* the done signal in the same window — a done
  signal files the whole freeform; new notes go in the now-empty file.
- Automatic vault reorganization — the agent only appends/creates, same as scans.
- A grep-based done-signal list — Claude judges it so phrasing stays free.
