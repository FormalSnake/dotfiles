# Obsidian vault + free multi-device sync + AI notebook-scan pipeline — design

Date: 2026-07-15
Hosts: `macbook` (nix-darwin, always-on host), `g815` (NixOS laptop), iPhone, iPad

## Goals

1. One Obsidian vault, synced free across g815, macbook, iPad, iPhone.
2. An AI pipeline: drop a photo of a notebook page into a watched folder from
   any device; an agent transcribes the handwriting to markdown and appends it
   to the right existing note or creates a new one — using the vault itself as
   context so it understands the owner's projects and terminology.
3. A cozy, non-overwhelming vault optimized for: random project notes, meeting
   notes, ideas, startup (cofounder) management, chaotic-mind capture.

## Decisions (locked, from brainstorming)

- **Sync: Self-hosted LiveSync** (CouchDB on the macbook + the
  `obsidian-livesync` community plugin on every device), reached over
  Tailscale. Rejected: iCloud+Syncthing bridge (double-hop conflicts, iCloud
  offloading), git-based (clunky iOS ritual).
- **AI pipeline host/brain: macbook + headless Claude Code** (`claude -p`).
  The agent gets vault access so append-vs-new filing is judged with full
  context of existing notes. Rejected: dumb CanaryLLM transcribe script (no
  vault awareness), g815 listener (laptop not always on).
- **Vault shape: cozy PARA-lite** — Home dashboard, Inbox, Projects, Startup,
  Meetings, Ideas, Archive, Attachments, `_inbox/scans/`. Rejected:
  daily-note-centric, flat+tags.

## Architecture

```
iPhone ─┐                        macbook
iPad  ──┼─ Tailscale (HTTPS) ──> tailscale serve ──> CouchDB 127.0.0.1:5984
g815  ──┘                        │
macbook (localhost) ────────────>┘
        every device runs the obsidian-livesync plugin, E2E-encrypted

iPhone photo ─> vault/_inbox/scans/ ── LiveSync ──> macbook vault copy
  launchd WatchPaths agent ─> claude -p (vision, vault cwd)
    ─> transcribe ─> append/create note ─> move image to Attachments/
```

### Sync backbone

- **CouchDB** via homebrew formula `couchdb` in `systems/macbook/homebrew.nix`
  (`homebrew.brews` with `restart_service = true`), bound to `127.0.0.1:5984`
  only — never a public interface.
- **LiveSync-required CouchDB settings** (single-node, admin auth,
  `require_valid_user`, CORS for `app://obsidian.md capacitor://localhost
  http://localhost`, raised `max_document_size`) written to CouchDB's
  `local.d` include dir. Admin password is an agenix secret
  (`secrets/couchdb-admin.age`), rendered at activation on the mac.
- **TLS + reachability:** `tailscale serve` exposes 5984 as
  `https://macbook.<tailnet>.ts.net` with a valid Let's Encrypt certificate.
  iOS Obsidian requires HTTPS with a valid cert for non-localhost sync, which
  is exactly what serve provides. `tailscale serve --bg` config persists across
  reboots (one-time imperative step, documented).
- **Plugin:** `obsidian-livesync` (vrtmrz) on all four devices, E2E encryption
  enabled — CouchDB stores ciphertext only. Devices 2–4 are onboarded with the
  plugin's encrypted **setup-URI** generated on the first device.
- **iOS prerequisite:** free Tailscale app on iPhone/iPad, signed into the
  tailnet.

### AI scan pipeline (macbook)

- New darwin mixin `modules/darwin/mixins/obsidian-scan-watcher.nix`:
  a `launchd.user.agents.obsidian-scan-watcher` with
  `WatchPaths = ~/Notes/_inbox/scans` running a script that:
  1. Takes an exclusive lock (skip if another run is active; launchd
     re-fires on further changes).
  2. Waits for each new image (`jpg/jpeg/png/heic`, non-recursive; ignores
     `failed/`) to settle (size stable) so half-synced files are never read.
  3. Runs `claude -p` with the vault as working directory, tool access
     restricted to the vault, and a prompt that instructs it to: read the
     image; transcribe handwriting to clean markdown (preserve headings,
     lists, sketches described in words); search existing notes to resolve
     project names and personal shorthand; then **append** to the matching
     note in Projects/Startup/Meetings/Ideas (with a `## Scanned YYYY-MM-DD`
     heading) or **create** a new note in the right folder; default to
     `Inbox/` when unsure. Never delete or rewrite existing content.
  4. On success: move the image to `Attachments/scans/YYYY/`, and the agent
     embeds a link to it in the note. On failure: move to
     `_inbox/scans/failed/` and append a line to `_inbox/scans/watcher.log`.
- Model: `sonnet` alias (vision + judgment, cheap enough per page); flag in
  the script so it's a one-line change.
- Idempotency: the scan folder only ever contains unprocessed work; processed
  and failed images are moved out, so re-fires are harmless.

### Capture from iPhone/iPad

- iOS Shortcut **"Scan to Notes"** (documented recipe; Shortcuts cannot be
  created remotely): take photo(s) → convert/resize to JPEG ≤ ~2000px →
  save to the Obsidian vault's `_inbox/scans/` via Files. LiveSync uploads it;
  the mac processes it within seconds of sync.
- Fallback that always works: put any image into `_inbox/scans/` from any
  device (Obsidian mobile, Files, Finder, g815).

### The vault

- Path `~/Notes` on both computers (per-device local path; LiveSync doesn't
  care that they match, but consistency is cozy).
- Skeleton: `Home.md`, `Inbox/`, `Projects/`, `Startup/`, `Meetings/`
  (`YYYY-MM-DD topic.md`), `Ideas/`, `Archive/`, `Attachments/`,
  `_inbox/scans/`.
- `.obsidian` bootstrap settings: new notes → `Inbox/`, attachments →
  `Attachments/`, Minimal theme, daily notes off, exactly one community
  plugin (LiveSync). `Home.md` is a small dashboard of links + a pinned
  starting point; each folder gets a one-line starter note.
- Vault content is personal data — it lives outside this repo and syncs via
  CouchDB. A bootstrap script creates it once on the first device.

## What changes in this repo

| Piece | Location |
|---|---|
| Obsidian app (Linux) | `users/kyandesutter/mixins/obsidian.nix` (nixpkgs `obsidian`, unfree already allowed) |
| Obsidian app (mac) | `obsidian` cask in `systems/macbook/homebrew.nix` |
| CouchDB service | `couchdb` formula in `systems/macbook/homebrew.nix` + config/secret wiring in a new `modules/darwin/mixins/obsidian-sync.nix` |
| Admin password | `secrets/couchdb-admin.age` + `secrets/secrets.nix` entry |
| Scan watcher | `modules/darwin/mixins/obsidian-scan-watcher.nix` (launchd agent + script) |
| Vault bootstrap | one-time script (run once, not a service) |
| Device onboarding + iOS Shortcut docs | a `Setup` note inside the vault itself (cozy: docs live where they're used), not repo markdown |

## Manual / owner-driven steps

1. `tailscale serve` one-time setup on the mac (Claude can drive over ssh;
   sudo may bounce to owner).
2. CouchDB first-run init (admin user, LiveSync settings) — scripted, needs
   the agenix secret present.
3. Generate LiveSync setup-URI on the first device; paste on the other three.
4. iOS: install Tailscale + Obsidian from the App Store, join tailnet, create
   empty vault, install LiveSync plugin, paste setup-URI, add the Shortcut.

## Error handling

- **CouchDB down / mac asleep:** LiveSync queues locally and syncs on
  reconnect; nothing is lost. The watcher only runs on the mac, so scans
  simply wait.
- **Half-synced images:** settle check (stable size) before processing.
- **Agent failure (bad image, API error):** image → `failed/`, line in
  `watcher.log`, original never deleted.
- **Sync conflicts:** LiveSync per-document conflict resolution dialog;
  E2E passphrase mismatch fails loudly at setup time.
- **nvidia/power invariants (g815):** untouched — this design adds only a
  desktop app and a home mixin on Linux.

## Testing / verification

1. `curl` CouchDB `_up` locally on the mac, then via the tailnet HTTPS URL
   from g815.
2. Round-trip test: edit a note on g815, see it on the mac (and later iOS).
3. Pipeline test: drop a sample handwriting photo into `_inbox/scans/` on
   g815; verify the mac produces a transcribed note filed correctly, image
   archived, link embedded.
4. Failure test: drop a corrupt/non-image file; verify it lands in `failed/`
   with a log line and the watcher keeps working.

## Non-goals

- Paid Obsidian Sync/Publish; Syncthing on iOS (Möbius is paid).
- Large-binary vault usage (PDF dumps) — LiveSync chunks attachments into
  CouchDB; notebook-page JPEGs are fine, gigabyte media is not. Revisit if
  needs change.
- Automatic vault reorganization by the agent (it only appends/creates).
- Daily notes, dataview dashboards, plugin zoos — cozy means few moving parts.
