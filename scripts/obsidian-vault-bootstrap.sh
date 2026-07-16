#!/usr/bin/env bash
# One-time Obsidian vault bootstrap (idempotent — skips anything that exists).
#   full   — first device: folders + starter notes + .obsidian (plugin/theme/settings)
#   client — later devices: folders + .obsidian only; note content arrives via LiveSync
set -euo pipefail

MODE="${1:?usage: obsidian-vault-bootstrap.sh <full|client> [vault-path]}"
VAULT="${2:-$HOME/Notes}"
[ "$MODE" = full ] || [ "$MODE" = client ] || { echo "mode must be full|client" >&2; exit 1; }

mkdir -p "$VAULT"/{Inbox,Projects,Startup,Meetings,Ideas,Archive,Attachments,_inbox/scans/failed} \
         "$VAULT"/.obsidian/{plugins/obsidian-livesync,themes/Minimal}

# --- .obsidian settings (only if absent — Obsidian owns these after first run) ---
put() { # put <path> <<EOF...  (write only if missing)
  local f="$VAULT/$1"
  [ -e "$f" ] && { echo "skip  $1"; cat >/dev/null; return; }
  cat > "$f"; echo "wrote $1"
}

put .obsidian/app.json <<'EOF'
{
  "newFileLocation": "folder",
  "newFileFolderPath": "Inbox",
  "attachmentFolderPath": "Attachments",
  "alwaysUpdateLinks": true,
  "showUnsupportedFiles": true
}
EOF

put .obsidian/appearance.json <<'EOF'
{
  "cssTheme": "Minimal"
}
EOF

put .obsidian/community-plugins.json <<'EOF'
["obsidian-livesync"]
EOF

# --- LiveSync plugin (latest release assets) + Minimal theme ---
fetch() { # fetch <url> <dest-rel>  (only if missing)
  local f="$VAULT/$2"
  [ -e "$f" ] && { echo "skip  $2"; return; }
  curl -fsSL "$1" -o "$f"; echo "fetch $2"
}
LS=https://github.com/vrtmrz/obsidian-livesync/releases/latest/download
fetch "$LS/main.js"       .obsidian/plugins/obsidian-livesync/main.js
fetch "$LS/manifest.json" .obsidian/plugins/obsidian-livesync/manifest.json
fetch "$LS/styles.css"    .obsidian/plugins/obsidian-livesync/styles.css
MIN=https://raw.githubusercontent.com/kepano/obsidian-minimal/master
fetch "$MIN/manifest.json" .obsidian/themes/Minimal/manifest.json
fetch "$MIN/theme.css"     .obsidian/themes/Minimal/theme.css

[ "$MODE" = client ] && { echo "client bootstrap done: $VAULT"; exit 0; }

# --- starter notes (full mode only) ---
put Home.md <<'EOF'
# 🏠 Home

Welcome back. Everything has a place — and Inbox is a fine place.

- 📥 [[Inbox/README|Inbox]] — anything unsorted lands here
- 🚀 [[Projects/README|Projects]] — one note per project
- 🏢 [[Startup/README|Startup]] — cofounder things
- 📅 [[Meetings/README|Meetings]] — `YYYY-MM-DD topic`
- 💡 [[Ideas/README|Ideas]] — one idea, one note
- 🛠 [[Setup]] — devices, sync & the scan pipeline

> 📷 Photograph a notebook page into `_inbox/scans/` (or use the *Scan to
> Notes* shortcut) and it becomes a note on its own.
>
> ✍️ Or just type into [[Inbox/index|📥 index]] — end a note however you like
> ("done", "dat was het", "file this") and it gets filed for you.
EOF

put Inbox/README.md <<'EOF'
Unsorted things live here guilt-free. Move them out when they've earned a home — or don't.
EOF

put Inbox/index.md <<'EOF'
# Inbox

<!-- watcher log below (do not edit) -->
## Log
EOF

put Projects/README.md <<'EOF'
One note per project. Scanned pages about a project get appended to its note automatically.
EOF

put Startup/README.md <<'EOF'
Cofounder HQ — strategy, tasks, numbers, people.
EOF

put Meetings/README.md <<'EOF'
One note per meeting, named `YYYY-MM-DD topic.md`. Scanned meeting pages land here on their own.
EOF

put Ideas/README.md <<'EOF'
One idea = one note. Half-formed is fine; that's what this folder is for.
EOF

put Setup.md <<'EOF'
# 🛠 Setup — devices, sync, scan pipeline

## Sync (Self-hosted LiveSync)
CouchDB runs on the macbook, reachable **only over Tailscale** at
`https://<mac-tailnet-name>/` (fill in from `tailscale status`). Credentials:
user `admin`, password in `/run/agenix/couchdb-admin` on either computer.
Database: `notes`. End-to-end encryption is ON — the passphrase lives in your
head/password manager, not on the server.

## Adding a new device
1. Install **Tailscale** (App Store / package) and sign into the tailnet.
2. Install **Obsidian**; create/open an empty vault named `Notes`.
   (On computers: run `scripts/obsidian-vault-bootstrap.sh client` first and
   open `~/Notes` instead.)
3. On iOS only: Settings → Community plugins → turn off Restricted mode →
   Browse → install **Self-hosted LiveSync** and enable it.
4. On an already-synced device: LiveSync settings → 🧰 Setup → **Copy setup
   URI** (choose a one-time passphrase).
5. On the new device: command palette → **Self-hosted LiveSync: Open setup
   URI**, paste, enter the passphrase, choose **Set it up as secondary**.
6. Wait for the first replication to finish. Done.

## iPhone/iPad shortcut — "Scan to Notes"
Shortcuts app → + → name it **Scan to Notes**:
1. **Take Photo** (allow multiple: on).
2. **Convert Image** → JPEG (this also drops HEIC).
3. **Resize Image** → width 2000, height auto.
4. **Save File** → service: *Files*, destination folder:
   `On My iPhone/Obsidian/Notes/_inbox/scans`, ask where to save: off.
Add it to the Home Screen / Action Button. Snap a page; the macbook transcribes
it into the right note within a minute of sync.

## How the scan pipeline files things
Watcher on the macbook (launchd, `scripts/obsidian-scan-watcher.sh`) sees a new
image in `_inbox/scans/`, archives it to `Attachments/scans/<year>/`, and runs
headless Claude with this vault as context. It appends to the matching
project/meeting/idea note (under a `## Scanned <date>` heading) or creates a
new note; unsure → `Inbox/`. Failures land in `_inbox/scans/failed/` with a
line in `_inbox/scans/watcher.log`. It never edits or deletes existing prose.

## How the text inbox files things
Type freeform into `Inbox/index.md` (the area above the log sentinel) from any
device. A second macbook watcher (launchd, `scripts/obsidian-note-watcher.sh`)
polls every 5 minutes and, when your text ends with a natural "done" signal
("done", "dat was het", "file this", …), runs headless Claude to file it into
the right note — creating the project note if it's new, grouping bugs and
feature ideas. On success it clears the freeform and prepends a dated copy under
`## Log`; no signal yet leaves it alone. Nothing below the sentinel is yours to
edit. Log/debug in `_inbox/note-watcher.log`.
EOF

echo "full bootstrap done: $VAULT"
