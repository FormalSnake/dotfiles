# Obsidian LiveSync + AI Scan Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One free-synced Obsidian vault across g815/macbook/iPad/iPhone (CouchDB + LiveSync over Tailscale) plus a macbook launchd watcher that runs headless Claude to transcribe notebook-page photos into the right notes.

**Architecture:** CouchDB (homebrew) on the macbook, localhost-only, exposed over the tailnet as HTTPS by `tailscale serve`; every device runs the `obsidian-livesync` plugin with E2E encryption. A launchd `WatchPaths` agent on the macbook runs a repo script (live-editable, same pattern as `auto-update.nix`) that archives each new scan image and runs `claude -p` with the vault as cwd to transcribe + file it. The vault itself is bootstrapped by a one-time repo script.

**Tech Stack:** nix-darwin + home-manager, agenix, homebrew (`couchdb` formula, `obsidian` cask), nixpkgs `obsidian` (Linux), Tailscale serve, Claude Code headless, Obsidian plugins: `obsidian-livesync` (vrtmrz), theme: Minimal (kepano).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-15-obsidian-livesync-design.md`.
- Vault path is `~/Notes` on both computers. Skeleton: `Home.md`, `Inbox/`, `Projects/`, `Startup/`, `Meetings/`, `Ideas/`, `Archive/`, `Attachments/`, `_inbox/scans/`.
- CouchDB binds `127.0.0.1:5984` only. Never a public interface. TLS/reachability is `tailscale serve` exclusively.
- Admin password lives in `secrets/couchdb-admin.age`; mounted at `/run/agenix/couchdb-admin`.
- Exactly one community plugin (LiveSync) + Minimal theme. Daily notes stay off.
- The watcher may only append/create notes (prompt-enforced) and never deletes originals: success → `Attachments/scans/YYYY/`, failure → `_inbox/scans/failed/`.
- g815 power/nvidia mixins untouched (this plan adds only a desktop app + home mixin on Linux).
- Commits: conventional style (`feat(scope): …`), no co-author lines, no descriptions.
- **Deviation from spec (accepted):** CouchDB's LiveSync settings + admin password are applied by a one-time idempotent init script (`scripts/couchdb-livesync-init.sh`), not nix activation — CouchDB rewrites its own `local.ini` to hash the admin password, so a nix-managed ini would churn every rebuild. There is consequently no `modules/darwin/mixins/obsidian-sync.nix`; the secret lives in the existing `agenix.nix` mixins.
- Rebuild commands: g815 → `sudo nixos-rebuild switch --flake ~/.config/nix#g815`; macbook → `ssh macbook`, `cd ~/.config/nix && git pull && just r`. **Both prompt for sudo (and ssh may prompt for auth) — if a step blocks, stop and hand exactly that command to the owner via `! <cmd>`, then continue.**
- GUI steps inside Obsidian (LiveSync wizard, setup-URI paste, iOS installs) cannot be driven from the CLI — present them to the owner as a checklist and wait for confirmation.

---

### Task 1: CouchDB admin secret (`couchdb-admin.age`)

**Files:**
- Modify: `secrets/secrets.nix` (add recipient entry)
- Create: `secrets/couchdb-admin.age`
- Modify: `modules/darwin/mixins/agenix.nix` (add secret to the `secrets` set)
- Modify: `modules/nixos/mixins/agenix.nix` (same — lets the g815 LiveSync wizard read the password without ssh-ing to the mac)

**Interfaces:**
- Produces: `/run/agenix/couchdb-admin` on both hosts (single line, hex password, no trailing newline requirements — consumers `cat` it).

- [ ] **Step 1: Add the recipient entry to `secrets/secrets.nix`**

Append inside the attrset (match existing alignment):

```nix
  "couchdb-admin.age".publicKeys        = [ kyan ];
```

- [ ] **Step 2: Generate and encrypt the password**

```bash
cd ~/.config/nix/secrets
nix shell nixpkgs#age -c sh -c \
  'openssl rand -hex 24 | age -e -r age1fg5dvcv49wmf6dz4zdan6yyvqfc6wangmlc0ff3rfwwuphy2fsfsk3hufv -o couchdb-admin.age'
```

- [ ] **Step 3: Verify it decrypts with the local identity**

Run: `nix shell nixpkgs#age -c age -d -i ~/.config/age/keys.txt ~/.config/nix/secrets/couchdb-admin.age | wc -c`
Expected: `49` (48 hex chars + newline). Do not print the password itself into logs.

- [ ] **Step 4: Wire the secret into both agenix mixins**

In `modules/darwin/mixins/agenix.nix` and `modules/nixos/mixins/agenix.nix`, add one line to the `secrets` attrset (both use the same `mkSecret` helper):

```nix
        couchdb-admin      = mkSecret "couchdb-admin";
```

- [ ] **Step 5: Verify both configs still evaluate**

```bash
cd ~/.config/nix && git add -A secrets modules
nix eval '.#nixosConfigurations.g815.config.system.stateVersion'
nix eval '.#darwinConfigurations.macbook.config.system.stateVersion'
```

Expected: both print a version string, no eval errors.

- [ ] **Step 6: Commit**

```bash
git commit -m "feat(secrets): add couchdb-admin secret for obsidian livesync"
```

---

### Task 2: Obsidian on Linux (g815)

**Files:**
- Create: `users/kyandesutter/mixins/obsidian.nix`
- Modify: `users/kyandesutter/linux.nix` (add import)

**Interfaces:**
- Produces: `obsidian` binary/desktop app on g815.

- [ ] **Step 1: Create the mixin**

`users/kyandesutter/mixins/obsidian.nix`:

```nix
{ pkgs, ... }:
{
  # Obsidian (unfree — allowUnfree is global in modules/shared/mixins/nix.nix).
  # Vault lives at ~/Notes, synced via Self-hosted LiveSync (CouchDB on the
  # macbook over Tailscale) — see docs/superpowers/specs/2026-07-15-obsidian-livesync-design.md.
  home.packages = [ pkgs.obsidian ];
}
```

- [ ] **Step 2: Import it in `users/kyandesutter/linux.nix`**

Add to the `imports` list (after `./mixins/godot.nix`):

```nix
    ./mixins/obsidian.nix
```

- [ ] **Step 3: Rebuild g815**

```bash
cd ~/.config/nix && git add -A
sudo nixos-rebuild switch --flake ~/.config/nix#g815
```

Sudo caveat applies — hand to owner if the prompt blocks.

- [ ] **Step 4: Verify**

Run: `which obsidian && ls /run/agenix/couchdb-admin`
Expected: a store path for obsidian, and the secret file exists (Task 1's nixos wiring is live).

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(home): add obsidian on linux"
```

---

### Task 3: Macbook homebrew entries (CouchDB + Obsidian cask)

**Files:**
- Modify: `systems/macbook/homebrew.nix`

**Interfaces:**
- Produces (after Task 7's mac rebuild): `couchdb` running as a brew service on `127.0.0.1:5984`; `Obsidian.app` installed.

- [ ] **Step 1: Add the brew (as an attrset — it must run as a service)**

In the `brews` list of `systems/macbook/homebrew.nix`:

```nix
      {
        # Obsidian LiveSync backend. Binds 127.0.0.1:5984 (CouchDB default);
        # exposed to the tailnet via `tailscale serve` only. Config/init:
        # scripts/couchdb-livesync-init.sh (one-time).
        name = "couchdb";
        start_service = true;
        restart_service = "changed";
      }
```

- [ ] **Step 2: Add the cask**

In the `casks` list (alphabetical-ish placement near the other apps):

```nix
      "obsidian"
```

- [ ] **Step 3: Verify eval**

Run: `cd ~/.config/nix && git add -A && nix eval '.#darwinConfigurations.macbook.config.system.stateVersion'`
Expected: version string, no error.

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(macbook): add couchdb service and obsidian cask"
```

---

### Task 4: Vault bootstrap script

**Files:**
- Create: `scripts/obsidian-vault-bootstrap.sh` (executable)

**Interfaces:**
- Consumes: nothing from other tasks (network access to GitHub for plugin/theme files).
- Produces: `obsidian-vault-bootstrap.sh <full|client> [vault-path]` — `full` = folders + starter notes + `.obsidian` (settings, LiveSync plugin, Minimal theme); `client` = folders + `.obsidian` only (content arrives via sync). Idempotent: never overwrites an existing file.

- [ ] **Step 1: Write the script**

`scripts/obsidian-vault-bootstrap.sh`:

```bash
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
EOF

put Inbox/README.md <<'EOF'
Unsorted things live here guilt-free. Move them out when they've earned a home — or don't.
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
EOF

echo "full bootstrap done: $VAULT"
```

- [ ] **Step 2: Make it executable and test into a scratch dir (both modes)**

```bash
chmod +x ~/.config/nix/scripts/obsidian-vault-bootstrap.sh
T=$(mktemp -d)
~/.config/nix/scripts/obsidian-vault-bootstrap.sh full "$T/v"
ls "$T/v" "$T/v/.obsidian/plugins/obsidian-livesync" "$T/v/.obsidian/themes/Minimal"
~/.config/nix/scripts/obsidian-vault-bootstrap.sh full "$T/v"   # idempotency: all "skip"
~/.config/nix/scripts/obsidian-vault-bootstrap.sh client "$T/c"
ls "$T/c"; rm -rf "$T"
```

Expected: first run writes/fetches everything (`main.js` is ~1MB+); second run prints only `skip` lines; client dir has folders + `.obsidian` but no `Home.md`.

- [ ] **Step 3: Commit**

```bash
cd ~/.config/nix && git add scripts/obsidian-vault-bootstrap.sh
git commit -m "feat(scripts): add obsidian vault bootstrap"
```

---

### Task 5: CouchDB LiveSync init script

**Files:**
- Create: `scripts/couchdb-livesync-init.sh` (executable; runs **on the macbook**)

**Interfaces:**
- Consumes: `/run/agenix/couchdb-admin` (Task 1), brew-installed couchdb (Task 3, live after Task 7).
- Produces: CouchDB configured for LiveSync (admin auth, CORS, size limits) on `127.0.0.1:5984`. Idempotent via a marker line in `local.ini`.

- [ ] **Step 1: Write the script**

`scripts/couchdb-livesync-init.sh`:

```bash
#!/usr/bin/env bash
# One-time CouchDB config for Obsidian Self-hosted LiveSync (macbook).
# Appends a marked block to local.ini; CouchDB hashes the [admins] password
# in place on next start (that's why nix must NOT own this file).
set -euo pipefail

SECRET=/run/agenix/couchdb-admin
[ -r "$SECRET" ] || { echo "missing $SECRET — rebuild with the agenix change first" >&2; exit 1; }
PW=$(cat "$SECRET")

PREFIX=$(brew --prefix)
INI="$PREFIX/etc/couchdb/local.ini"
[ -f "$INI" ] || INI="$PREFIX/etc/local.ini"
[ -f "$INI" ] || { echo "no local.ini under $PREFIX/etc — is couchdb installed?" >&2; exit 1; }
echo "using $INI"

MARK="; --- obsidian-livesync (managed once by couchdb-livesync-init.sh) ---"
if grep -qF "$MARK" "$INI"; then
  echo "already configured — nothing to do"
else
  cat >> "$INI" <<EOF

$MARK
[couchdb]
single_node = true
max_document_size = 50000000

[chttpd]
require_valid_user = true
max_http_request_size = 4294967296
enable_cors = true

[chttpd_auth]
require_valid_user = true
authentication_redirect = /_utils/session.html

[httpd]
WWW-Authenticate = Basic realm="couchdb"
enable_cors = true

[cors]
origins = app://obsidian.md,capacitor://localhost,http://localhost
credentials = true
headers = accept, authorization, content-type, origin, referer
methods = GET,PUT,POST,HEAD,DELETE
max_age = 3600

[admins]
admin = $PW
EOF
  brew services restart couchdb
fi

# wait for _up, then prove auth + create the LiveSync database
for i in $(seq 1 30); do
  curl -fsS -u "admin:$PW" http://127.0.0.1:5984/_up >/dev/null 2>&1 && break
  sleep 1
  [ "$i" = 30 ] && { echo "couchdb did not come up" >&2; exit 1; }
done
curl -fsS -u "admin:$PW" -X PUT http://127.0.0.1:5984/notes >/dev/null 2>&1 || true
curl -fsS -u "admin:$PW" http://127.0.0.1:5984/notes | head -c 200; echo
echo "couchdb ready for livesync"
```

- [ ] **Step 2: Syntax-check and commit** (it can only *run* on the mac, Task 8)

```bash
chmod +x ~/.config/nix/scripts/couchdb-livesync-init.sh
bash -n ~/.config/nix/scripts/couchdb-livesync-init.sh && echo SYNTAX-OK
cd ~/.config/nix && git add scripts/couchdb-livesync-init.sh
git commit -m "feat(scripts): add couchdb livesync init"
```

Expected: `SYNTAX-OK`.

---

### Task 6: Scan watcher (launchd mixin + script)

**Files:**
- Create: `scripts/obsidian-scan-watcher.sh` (executable; runs on the macbook)
- Create: `modules/darwin/mixins/obsidian-scan-watcher.nix`
- Modify: `modules/darwin/default.nix` (add import)

**Interfaces:**
- Consumes: `~/Notes` vault (Tasks 4/9), `claude` from the per-user home-manager profile.
- Produces: `launchd.user.agents.obsidian-scan-watcher` firing on changes under `~/Notes/_inbox/scans`; log at `~/Library/Logs/obsidian-scan-watcher.log` and `_inbox/scans/watcher.log`.

- [ ] **Step 1: Write the watcher script**

`scripts/obsidian-scan-watcher.sh`:

```bash
#!/bin/bash
# Obsidian notebook-scan pipeline (macbook). Fired by launchd WatchPaths on
# ~/Notes/_inbox/scans (+ a slow StartInterval safety net). For each settled
# image: archive to Attachments/scans/<year>/, then let headless Claude
# transcribe + file it with the vault as context. Append-only by prompt.
set -uo pipefail

VAULT="$HOME/Notes"
SCANS="$VAULT/_inbox/scans"
LOG="$SCANS/watcher.log"
[ -d "$SCANS" ] || exit 0

# mkdir-based lock (no flock on macOS); a queued launchd fire retries later.
LOCK="$SCANS/.watcher.lock"
if ! mkdir "$LOCK" 2>/dev/null; then exit 0; fi
trap 'rmdir "$LOCK"' EXIT

shopt -s nullglob nocaseglob
for img in "$SCANS"/*.{jpg,jpeg,png,webp,heic}; do
  [ -f "$img" ] || continue

  # settle check: skip files still being synced in; next fire picks them up
  s1=$(stat -f%z "$img"); sleep 2; s2=$(stat -f%z "$img")
  [ "$s1" = "$s2" ] || continue

  base=$(basename "$img")

  # HEIC → JPEG (Claude's Read tool can't open HEIC); sips ships with macOS
  case "$img" in
    *.heic|*.HEIC)
      jpg="${img%.*}.jpg"
      if sips -s format jpeg "$img" --out "$jpg" >/dev/null 2>&1; then
        rm -f "$img"; img="$jpg"; base=$(basename "$img")
      else
        mkdir -p "$SCANS/failed"; mv "$img" "$SCANS/failed/$base"
        echo "$(date -Iseconds) FAILED(heic-convert) $base" >> "$LOG"; continue
      fi ;;
  esac

  year=$(date +%Y)
  mkdir -p "$VAULT/Attachments/scans/$year" "$SCANS/failed"
  stamped="$(date +%Y%m%d-%H%M%S)-$base"
  rel="Attachments/scans/$year/$stamped"
  mv "$img" "$VAULT/$rel"

  prompt="You are the notebook-scan assistant for this Obsidian vault (the current directory).
A photo of handwritten notebook page(s) is at: $rel

1. Read the image and transcribe the handwriting into clean markdown — keep the
   author's headings/lists/emphasis; describe sketches or diagrams briefly in
   [square brackets]. Don't invent content you can't read; mark it '(illegible)'.
2. Read Home.md, then search existing notes (Projects/, Startup/, Meetings/,
   Ideas/, Inbox/) to resolve project names and the author's personal shorthand —
   use existing notes to interpret ambiguous terms.
3. File it: if the content clearly belongs to an existing note, APPEND to that
   note under a new heading '## Scanned $(date +%Y-%m-%d)'. Otherwise create a
   new note in the best-fitting folder (Meetings/ notes are named
   'YYYY-MM-DD topic.md'). If genuinely unsure, create it in Inbox/.
4. End the appended/new section with an embed of the original page: ![[$rel]]
5. NEVER delete, rewrite, or reorder existing content — append only. No YAML
   frontmatter. Keep the markdown plain and calm."

  if (cd "$VAULT" && claude -p "$prompt" \
        --model sonnet --max-turns 30 \
        --allowedTools "Read,Glob,Grep,Write,Edit") >> "$LOG" 2>&1; then
    echo "$(date -Iseconds) OK $base -> $rel" >> "$LOG"
  else
    mv "$VAULT/$rel" "$SCANS/failed/$base"
    echo "$(date -Iseconds) FAILED(agent) $base" >> "$LOG"
  fi
done
```

- [ ] **Step 2: Syntax-check the script**

```bash
chmod +x ~/.config/nix/scripts/obsidian-scan-watcher.sh
bash -n ~/.config/nix/scripts/obsidian-scan-watcher.sh && echo SYNTAX-OK
```

Expected: `SYNTAX-OK`.

- [ ] **Step 3: Write the launchd mixin**

`modules/darwin/mixins/obsidian-scan-watcher.nix`:

```nix
{ config, ... }:
let
  home = config.users.users.kyandesutter.home;
  flakeDir = "${home}/.config/nix";
in
{
  # Notebook-scan pipeline: images synced into the vault's scan inbox are
  # transcribed to notes by headless Claude. The script lives in the repo
  # (live-editable without a rebuild — same pattern as auto-update.nix).
  # WatchPaths fires on any change under the dir; the script is idempotent
  # (processed/failed images are moved out) and self-locks, so extra fires
  # are harmless. StartInterval is the safety net for missed events / the
  # dir not existing at agent load time.
  launchd.user.agents.obsidian-scan-watcher = {
    serviceConfig = {
      Label = "kyan.obsidian-scan-watcher";
      ProgramArguments = [
        "/bin/bash"
        "-lc"
        "${flakeDir}/scripts/obsidian-scan-watcher.sh"
      ];
      EnvironmentVariables = {
        PATH = "/etc/profiles/per-user/kyandesutter/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      WatchPaths = [ "${home}/Notes/_inbox/scans" ];
      StartInterval = 600;
      ThrottleInterval = 15;
      RunAtLoad = true;
      StandardOutPath = "${home}/Library/Logs/obsidian-scan-watcher.log";
      StandardErrorPath = "${home}/Library/Logs/obsidian-scan-watcher.log";
    };
  };
}
```

- [ ] **Step 4: Import it in `modules/darwin/default.nix`**

Add after `./mixins/remote-access.nix`:

```nix
      ./mixins/obsidian-scan-watcher.nix
```

- [ ] **Step 5: Verify eval and commit**

```bash
cd ~/.config/nix && git add -A
nix eval '.#darwinConfigurations.macbook.config.system.stateVersion'
git commit -m "feat(macbook): add obsidian notebook-scan watcher"
```

Expected: version string, then a clean commit.

---

### Task 7: Macbook sync + rebuild

**Files:** none (deploy step).

**Interfaces:**
- Produces: couchdb brew service running, Obsidian.app installed, watcher agent loaded, `/run/agenix/couchdb-admin` present on the mac.

- [ ] **Step 1: Push from g815**

```bash
cd ~/.config/nix && git push
```

- [ ] **Step 2: Pull + rebuild on the mac** (ssh/sudo caveat — hand to owner if blocked)

```bash
ssh macbook 'cd ~/.config/nix && git pull && just r'
```

- [ ] **Step 3: Verify on the mac**

```bash
ssh macbook 'curl -s http://127.0.0.1:5984/ | head -c 120; echo; \
  ls /run/agenix/couchdb-admin; \
  launchctl list | grep kyan.obsidian-scan-watcher; \
  ls /Applications/Obsidian.app >/dev/null && echo OBSIDIAN-OK'
```

Expected: a CouchDB JSON banner (`{"couchdb":"Welcome"...}` — auth not yet required until init), the secret path, one launchd row, `OBSIDIAN-OK`.

---

### Task 8: CouchDB init + tailscale serve

**Files:** none (runs Task 5's script on the mac).

**Interfaces:**
- Produces: authenticated CouchDB with the `notes` DB; HTTPS endpoint `https://<mac-dnsname>/` on the tailnet.

- [ ] **Step 1: Run the init script on the mac**

```bash
ssh macbook '~/.config/nix/scripts/couchdb-livesync-init.sh'
```

Expected: `using .../local.ini`, a brew services restart, then `couchdb ready for livesync`.

- [ ] **Step 2: Expose over the tailnet**

```bash
ssh macbook 'tailscale serve --bg 5984 && tailscale serve status'
```

Expected: serve config showing `https://<mac-name>.<tailnet>.ts.net/ -> http://127.0.0.1:5984`. If it errors about HTTPS certs, the owner must enable HTTPS in the Tailscale admin console (DNS page) once, then re-run.

- [ ] **Step 3: Verify from g815 (the URL every device will use)**

```bash
MAC=$(tailscale status --json | jq -r '.Peer[] | select(.HostName=="macbook" or (.DNSName|startswith("macbook."))) | .DNSName' | sed 's/\.$//')
echo "LiveSync URI: https://$MAC/"
curl -s -u "admin:$(cat /run/agenix/couchdb-admin)" "https://$MAC/_up"
```

Expected: `{"status":"ok"...}`. Record the URI for Task 9.

---

### Task 9: Vault bootstrap + LiveSync onboarding (g815 first, then mac)

**Files:** none (runs Task 4's script; GUI steps are owner checklists).

**Interfaces:**
- Consumes: bootstrap script, CouchDB URI + password (Task 8).
- Produces: a live synced vault on both computers; a setup-URI for the iOS devices.

- [ ] **Step 1: Bootstrap the full vault on g815**

```bash
~/.config/nix/scripts/obsidian-vault-bootstrap.sh full ~/Notes
ls ~/Notes
```

Expected: skeleton + `Home.md` + `Setup.md`, plugin and theme files fetched.

- [ ] **Step 2: Owner checklist — LiveSync wizard on g815** (present verbatim, wait for confirmation)

1. Open Obsidian → Open folder as vault → `~/Notes`. When prompted about community plugins, choose **Trust author and enable plugins**.
2. Settings → Appearance → confirm theme **Minimal** is active.
3. Settings → Self-hosted LiveSync → 🧰 Setup wizard → **Manual setup**:
   - URI: `https://<mac-dnsname>/` (from Task 8), Username: `admin`, Password: `cat /run/agenix/couchdb-admin`, Database: `notes`.
   - Enable **End-to-end encryption**; choose a passphrase and store it in 1Password.
   - Run **Check database configuration** — every check should pass or be fixable by its inline button.
   - Sync mode: **LiveSync**.
4. Wait for the first replication to complete (status in the ribbon).
5. LiveSync settings → 🧰 Setup → **Copy setup URI** (choose a one-time passphrase) — paste it somewhere reachable from the mac (e.g. a note in the vault itself, deleted after onboarding, or 1Password).

- [ ] **Step 3: Bootstrap the client vault on the mac**

```bash
ssh macbook '~/.config/nix/scripts/obsidian-vault-bootstrap.sh client ~/Notes && ls ~/Notes'
```

Expected: folders + `.obsidian` with plugin/theme; no `Home.md` (it will sync in).

- [ ] **Step 4: Owner checklist — mac onboarding** (at the mac, or via Jump Desktop)

1. Open Obsidian → Open folder as vault → `~/Notes` → **Trust author and enable plugins**.
2. Command palette → **Self-hosted LiveSync: Open setup URI** → paste the URI from Step 2.5, enter its passphrase, choose **Set it up as secondary**.
3. Wait for replication; `Home.md` and the skeleton notes appear.

- [ ] **Step 5: Round-trip sync test (automated check)**

```bash
echo "- sync test $(date -Iseconds) from g815" >> ~/Notes/Inbox/sync-test.md
sleep 20
ssh macbook 'cat ~/Notes/Inbox/sync-test.md'
ssh macbook 'echo "- and back from the mac" >> ~/Notes/Inbox/sync-test.md'
sleep 20
cat ~/Notes/Inbox/sync-test.md
```

Expected: both lines visible on both machines (LiveSync must be running in both Obsidian instances). Delete `Inbox/sync-test.md` afterwards.

---

### Task 10: End-to-end scan pipeline test + failure test

**Files:** none.

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Drop a real handwriting photo in from g815**

Ask the owner for a notebook-page photo (or photograph one with the iPhone once iOS is onboarded); place it at `~/Notes/_inbox/scans/test-page.jpg` on g815. Then:

```bash
sleep 30   # LiveSync -> mac, WatchPaths fires
ssh macbook 'tail -5 ~/Notes/_inbox/scans/watcher.log; ls ~/Notes/Attachments/scans/$(date +%Y)/'
```

Expected: an `OK test-page.jpg -> Attachments/scans/...` line and the archived image. Within another sync cycle the new/updated note appears on g815 — verify the transcription landed in a sensible folder with the `## Scanned` heading and the `![[...]]` embed.

- [ ] **Step 2: Failure path**

```bash
echo "not an image" > ~/Notes/_inbox/scans/broken.jpg
sleep 30
ssh macbook 'tail -3 ~/Notes/_inbox/scans/watcher.log; ls ~/Notes/_inbox/scans/failed/'
```

Expected: a `FAILED(agent) broken.jpg` line and the file preserved in `failed/`. (Claude's Read refuses the fake image; the agent exits nonzero or produces no edit — either way the wrapper moves it to `failed/`. If the agent instead exits 0, tighten the prompt with "If the file is not a readable image, exit with an error by not writing anything and stating IMAGE-UNREADABLE" and re-test — then the wrapper's exit-status check still governs.)

- [ ] **Step 3: iOS onboarding (owner, from the vault's `Setup.md`)**

Present the `Setup.md` checklist for iPhone + iPad (Tailscale app, Obsidian, LiveSync plugin, setup-URI, the *Scan to Notes* shortcut). Wait for the owner to confirm at least the iPhone syncs and a shortcut-captured photo flows end-to-end.

- [ ] **Step 4: Final push**

```bash
cd ~/.config/nix && git status   # expect clean or only plan-checkbox edits
git push
```

---

## Self-review notes

- Spec coverage: sync backbone (T1,3,5,7,8), scan pipeline (T6,10), capture shortcut (Setup.md in T4, verified T10.3), vault + cozy settings (T4,9), repo table rows all mapped (obsidian-sync.nix consciously replaced by the init script — recorded in Global Constraints), manual steps (T8–10 owner checklists), error handling (settle check, lock, failed/, watcher.log — T6; failure test T10.2), testing section (T8.3, T9.5, T10).
- Types/paths consistent: vault `~/Notes`, scans `_inbox/scans`, archive `Attachments/scans/YYYY/`, DB `notes`, secret `/run/agenix/couchdb-admin`, label `kyan.obsidian-scan-watcher` throughout.
