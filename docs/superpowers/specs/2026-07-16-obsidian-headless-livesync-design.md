# Headless LiveSync on the macbook — keep the vault current without the GUI — design

Date: 2026-07-16
Host: `macbook` (nix-darwin, always-on host)
Companion to: `2026-07-15-obsidian-livesync-design.md` (sync + scan pipeline),
`2026-07-16-obsidian-note-inbox-design.md` (free-text note inbox)

## Problem

Both filing pipelines (the scan watcher and the note-inbox watcher) read the
vault's files **from the mac's disk**. But LiveSync only writes the mac's
filesystem while the Obsidian **app is open and actively replicating**. When
Obsidian isn't focused on the vault — or has the note open in an editor buffer —
edits made on another device sit in CouchDB and never reach the mac's disk, so
the watchers process stale files. This is exactly what bit the note inbox: a note
finished on the iPhone ("Dat is het") reached CouchDB and the phone, but the
mac's on-disk copy stayed truncated, so the watcher correctly-but-uselessly
reported `PENDING` for hours.

The fix is to keep the mac's `~/Notes` current **headlessly**, independent of the
GUI app's focus and disk-flush timing.

## Decisions (locked, from research)

- **Use the official headless CLI**, `vrtmrz/obsidian-livesync` at `src/apps/cli`
  (the "self-hosted-livesync-cli"), running its `daemon` command: an initial
  mirror scan then continuous two-way sync — CouchDB → filesystem via the
  `_changes` feed (near real-time), filesystem → CouchDB via a file watcher.
- **Rejected: livesync-bridge** (`vrtmrz/livesync-bridge`). The maintainer calls
  it outdated, and two open bugs hit our exact setup (E2EE on, real Obsidian
  clients in the mesh): #12 corrupts encrypted round-trips between the bridge and
  real clients, and #46 silently stalls any document over ~30 KB because its
  vendored crypto lib is ~7 months stale. The CLI is built from the **same shared
  core as the plugin**, so that class of version-drift bug can't occur, and it has
  real conflict handling the bridge lacks. Keep the bridge only as a documented
  fallback.
- **This replaces running Obsidian.app on the mac** as a sync device (the
  `2026-07-15` plan's Task 9 Step 4). Running a headless daemon **and** Obsidian.app
  against the same `~/Notes` on the same host is a hazard: two uncoordinated
  watchers pushing to the same CouchDB, last-write-wins, silent conflict loss. The
  daemon takes over that role; the mac no longer needs the GUI app for sync (it can
  still be opened to *edit*, but sync no longer depends on it).
- **Secrets stay out of the Nix store.** The CLI's settings file (CouchDB password
  + E2EE passphrase) is templated at launchd-start from agenix secrets, the same
  pattern the CouchDB init already uses for `local.ini` — never rendered into a
  world-readable store path.

## Architecture

```
other devices ──LiveSync──> CouchDB (mac, 127.0.0.1:5984, agenix-authed)
                                │
                    self-hosted-livesync-cli  (launchd, KeepAlive, Node daemon)
                       _changes feed ─> writes plaintext .md into ~/Notes
                       file watcher   ─> pushes local edits back into CouchDB
                                │
                    scan + note watchers read a now-always-current ~/Notes
```

## Runtime & build

- **Node.js** (nixpkgs `nodejs`, available on aarch64-darwin). No dedicated
  nixpkgs package for the CLI — build it from a clone, the same imperative
  approach the vault bootstrap uses for plugin assets.
- One-time build (owner/manual, scripted): `git clone --recurse-submodules
  https://github.com/vrtmrz/obsidian-livesync` (the `src/lib` core is a submodule),
  then `npm ci && npm run build -w self-hosted-livesync-cli`, producing
  `src/apps/cli/dist/index.cjs`.
- Run (daemon is the default subcommand): `node <clone>/src/apps/cli/dist/index.cjs
  <vault-path>`. `--interval N` switches CouchDB→FS from the live `_changes` feed
  to polling if the feed proves flaky; `--vault <path>` decouples the CLI's state
  dir (PouchDB/leveldb cursor + stat cache) from the `.md` directory if wanted.
- Pin the clone path and the state dir in the launchd job so a restart resumes
  from the saved `_changes` cursor instead of doing a full (E2EE-decrypting)
  rescan.

## Config

`.livesync/settings.json` inside the vault (the plugin's own settings schema):

```jsonc
{
  "couchDB_URI": "http://127.0.0.1:5984",
  "couchDB_USER": "admin",
  "couchDB_PASSWORD": "<from agenix>",
  "couchDB_DBNAME": "notes",
  "encrypt": true,
  "passphrase": "<from agenix>",
  "liveSync": true,
  "isConfigured": true
}
```

- Templated at launchd-start by a small script from two agenix secrets
  (`secrets/couchdb-admin.age` reused for the password, a new
  `secrets/livesync-passphrase.age` for the E2EE passphrase), mirroring the
  CouchDB init's `local.ini` templating. The rendered file lives in the vault
  (mode 600), not the store.
- **Verify before finalizing (open item):** the CLI reportedly migrates the flat
  `couchDB_*` fields into an internal connection-string form (`remote-add` /
  `remote-set`) after first run; a provisioner that rewrites `settings.json` every
  start may fight that migration. Resolution options to test: template only when
  the file is absent, or drive initial setup once via `remote-add` and leave the
  file thereafter. Pick whichever survives the CLI's own migration.

## launchd service

New darwin mixin `modules/darwin/mixins/obsidian-livesync-daemon.nix`, shaped like
`obsidian-scan-watcher.nix`:

- `KeepAlive = true` (it's a long-running daemon, not a periodic job), `RunAtLoad`,
  `WorkingDirectory` pinned to the CLI clone, `ProgramArguments = [node, dist/index.cjs, "~/Notes"]`.
- `PATH` including the nix profile so `node` resolves; `StandardOut/ErrorPath` to
  `~/Library/Logs/obsidian-livesync-daemon.log`.
- A start-time exec wrapper (or a tiny repo script) renders `settings.json` from
  the agenix secrets before launching `node`.

## Conflict behaviour & interaction with the watchers

- The CLI flags conflicts rather than silently overwriting: `ls` marks conflicted
  files with `*`, `info <path>` shows revisions, `resolve <path> <rev>` keeps one.
  The mirror step compares `mtime` and pushes the newer side, but leaves genuinely
  conflicted docs flagged and skipped.
- The note-inbox watcher **rewrites `Inbox/index.md`** on a successful file. If a
  device edits that note at the same moment, the CLI flags a conflict instead of
  losing an edit; the filed text is also preserved in the note's `## Log` copy, so
  nothing is lost. Acceptable; document the `resolve` recipe in `Setup.md`.
- Loop safety: the daemon writing a file must not be seen by the watchers as
  "new user input" in a way that re-triggers filing. The scan watcher is safe (it
  moves images out). The note watcher's change-gate keys on the freeform hash, so a
  daemon-driven write of already-filed content (empty freeform) is a no-op.

## What changes in this repo

| Piece | Location |
|---|---|
| Daemon service | `modules/darwin/mixins/obsidian-livesync-daemon.nix` (new launchd agent) + wire into `modules/darwin/default.nix` |
| Settings templater | small repo script rendering `.livesync/settings.json` from agenix at start |
| E2EE passphrase secret | `secrets/livesync-passphrase.age` + `secrets/secrets.nix` entry |
| CLI build | one-time scripted clone + `npm run build` (imperative, like plugin-asset fetches); path pinned for the launchd job |
| Plan change | drop "install Obsidian.app on the mac as a sync device" from the `2026-07-15` plan (Task 9 Step 4) |
| Docs | update `Setup.md` seed: sync on the mac is the headless daemon, plus the conflict-`resolve` recipe |

## Manual / owner-driven steps

1. Build the CLI once (`npm run build`) — needs network + npm; scriptable but not a
   rebuild step.
2. Add `secrets/livesync-passphrase.age` (agenix; the same E2EE passphrase the
   LiveSync plugin uses).
3. First run may report `Remote database is locked … unlock from the Obsidian
   plugin` — there's no GUI here, so use the CLI's `remote-status` / `unlock-remote`
   / `mark-resolved` to clear it once.

## Testing / verification

1. **Freshness (the actual goal):** with Obsidian **closed** on the mac, edit a
   note on the iPhone; within seconds it appears in the mac's `~/Notes` on disk and
   the relevant watcher processes it. This is the case that failed before.
2. **Large note:** create/sync a note > 30 KB (or one with an embedded image); it
   must round-trip intact — the bridge's #46 stall must not reappear.
3. **Conflict:** edit the same note on two devices while the mac is offline; on
   reconnect the CLI flags it (`ls` shows `*`), and `resolve` keeps the chosen
   revision — no silent loss.
4. **Restart:** stop/start the launchd job; it resumes from the saved cursor
   without a full rescan (watch the log for a re-mirror storm).
5. **No GUI regression:** opening Obsidian on the mac to edit still works and does
   not double-sync or conflict with the daemon.

## Non-goals

- livesync-bridge (documented fallback only, given #12/#46).
- Keeping Obsidian.app on the mac as a sync device (the daemon replaces it).
- Multi-page scan batching (separate concern, its own spec if wanted).
- Packaging the CLI as a first-class nix derivation — revisit if the imperative
  build proves fragile.
