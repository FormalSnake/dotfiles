# Syncthing Wallpaper + Zen Profile Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Syncthing mesh (g815, e1504g, macbook-as-hub) sharing `~/Pictures/Wallpapers` and the live Zen profile, with 1Password state excluded from sync; g815 seeds the first sync and e1504g's profile is replaced except its 1Password login.

**Architecture:** A new gated NixOS mixin runs the system Syncthing service as `kyandesutter` on both laptops with fully declarative devices/folders (pinned tailscale + LAN addresses, discovery/relays off). The mac's existing `syncthing-app` is configured over SSH via its REST API. A home-manager activation fragment renders `.stignore` into the Zen profile (1Password's storage excluded by uuid resolved from `prefs.js`). Spec: `docs/superpowers/specs/2026-07-22-syncthing-wallpaper-zen-sync-design.md`.

**Tech Stack:** NixOS `services.syncthing`, zen-browser flake `activationFragments`, Syncthing REST API, ssh (e1504g has passwordless sudo; g815 rebuilds need the owner's sudo).

## Global Constraints

- Folder ids/paths: `wallpapers` → `~/Pictures/Wallpapers` (all three hosts); `zen-profile` → `~/.config/zen/default` (laptops) / `/Users/kyandesutter/Sync/zen-profile` (mac replica).
- Known addresses — g815: `100.114.32.78` / `192.168.86.95`; e1504g: `100.109.196.64` / `192.168.86.116`; macbook: `100.75.60.102` (no LAN pin). Sync port 22000.
- 1Password addon id (dir name literal): `{d634138d-c276-4fc8-924b-40a0ea21d284}`.
- No hardcoded `/home/...` in module bodies — derive from `config.users.users.kyandesutter.home`.
- Flakes only see git-tracked files: `git add` before every rebuild.
- g815 rebuilds prompt for sudo — hand that step to the owner (`! just r`) if it blocks. e1504g is driven over `ssh e1504g` with passwordless sudo.
- **Ordering is load-bearing:** e1504g's profile must be wiped and its Syncthing index reset BEFORE any peer connects, or its freshly-activated skeleton files (newer mtime) win conflicts against g815's real session. Tasks 5–8 must run in order.
- Zen must be closed on a machine whenever its profile is wiped, restored, or first-scanned.

---

### Task 1: Collect the three Syncthing device IDs

**Files:** none (runtime data gathering; output feeds Task 2).

**Interfaces:**
- Produces: three device IDs `G815_ID`, `E1504G_ID`, `MAC_ID` (58-char strings like `ABCDEFG-...`), substituted into Task 2's mixin.

- [ ] **Step 1: Generate the g815 identity** (pre-generating at the exact `configDir` the mixin will pin means the service later reuses these keys)

```bash
nix shell nixpkgs#syncthing -c syncthing generate --config="$HOME/.config/syncthing"
grep -o '<device id="[^"]*"' "$HOME/.config/syncthing/config.xml" | head -1
```

Expected: `<device id="XXXXXXX-..."` — record as `G815_ID`. (If `~/.config/syncthing/config.xml` already exists, skip generate and just grep.)

- [ ] **Step 2: Generate the e1504g identity**

```bash
ssh e1504g 'nix shell nixpkgs#syncthing -c syncthing generate --config="$HOME/.config/syncthing"; grep -o "<device id=\"[^\"]*\"" "$HOME/.config/syncthing/config.xml" | head -1'
```

Expected: same shape — record as `E1504G_ID`.

- [ ] **Step 3: Read the mac's identity (launch the app if it has never run)**

```bash
ssh macbook 'CFG="$HOME/Library/Application Support/Syncthing/config.xml"; if [ ! -f "$CFG" ]; then open -a Syncthing; sleep 15; fi; grep -o "<device id=\"[^\"]*\"" "$CFG" | head -1'
```

Expected: same shape — record as `MAC_ID`. If `open -a Syncthing` fails (app missing), stop and ask the owner to launch Syncthing once on the mac.

- [ ] **Step 4: Confirm Syncthing is actually running on the mac**

```bash
ssh macbook 'pgrep -x syncthing >/dev/null && echo running || echo NOT-RUNNING'
```

Expected: `running`. If `NOT-RUNNING`, `ssh macbook 'open -a Syncthing'` and re-check; if it still won't start, hand to the owner. Also ask the owner to confirm the app's "Start at login" preference is on (menu-bar icon → Preferences) — this is what makes the hub always-on.

---

### Task 2: NixOS syncthing mixin, wired into both hosts

**Files:**
- Create: `modules/nixos/mixins/syncthing.nix`
- Modify: `modules/nixos/default.nix` (imports list, after `./mixins/onepassword.nix`)
- Modify: `systems/g815/default.nix`, `systems/e1504g/default.nix` (enable flag)

**Interfaces:**
- Consumes: the three device IDs from Task 1.
- Produces: `kyan.syncthing.enable` option; a running `syncthing.service` (system unit, user `kyandesutter`, config at `~/.config/syncthing`) with folders `wallpapers` and `zen-profile` shared to all three devices.

- [ ] **Step 1: Write the mixin.** Create `modules/nixos/mixins/syncthing.nix` — replace the three `@..._ID@` markers with Task 1's real IDs:

```nix
{ config, lib, ... }:
let
  cfg = config.kyan.syncthing;
  home = config.users.users.kyandesutter.home;

  # Device IDs are the runtime-generated Syncthing identities (keys live in
  # ~/.config/syncthing on the laptops, ~/Library/Application Support/Syncthing
  # on the mac). A reinstalled machine gets a new ID that must be updated here.
  # Addresses: tailscale IP first, home-LAN lease second (same fallback
  # reasoning as the e1504g remote builder in systems/e1504g/default.nix).
  devices = {
    g815 = {
      id = "@G815_ID@";
      addresses = [
        "tcp://100.114.32.78:22000"
        "tcp://192.168.86.95:22000"
      ];
    };
    e1504g = {
      id = "@E1504G_ID@";
      addresses = [
        "tcp://100.109.196.64:22000"
        "tcp://192.168.86.116:22000"
      ];
    };
    macbook = {
      id = "@MAC_ID@";
      addresses = [ "tcp://100.75.60.102:22000" ];
    };
  };
  peers = lib.attrNames devices;
in
{
  options.kyan.syncthing.enable = lib.mkEnableOption "Syncthing mesh (wallpapers + zen profile) with the macbook as the always-on hub";

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      user = "kyandesutter";
      group = "users";
      dataDir = home;
      configDir = "${home}/.config/syncthing";
      overrideDevices = true;
      overrideFolders = true;
      settings = {
        options = {
          urAccepted = -1;
          # Addresses are pinned above; the tailnet reaches everywhere a
          # relay or discovery server would.
          globalAnnounceEnabled = false;
          localAnnounceEnabled = false;
          relaysEnabled = false;
          natEnabled = false;
        };
        inherit devices;
        folders = {
          wallpapers = {
            id = "wallpapers";
            path = "${home}/Pictures/Wallpapers";
            devices = peers;
          };
          # Live Zen profile. One browser at a time; .stignore (rendered by
          # mixins/zen.nix) excludes locks, crash state and 1Password.
          zen-profile = {
            id = "zen-profile";
            path = "${home}/.config/zen/default";
            devices = peers;
          };
        };
      };
    };

    # LAN fallback path; tailscale0 is already a trusted interface
    # (mixins/phone-integration.nix), so only the LAN needs the port.
    networking.firewall.allowedTCPPorts = [ 22000 ];
    networking.firewall.allowedUDPPorts = [ 22000 ];
  };
}
```

- [ ] **Step 2: Import it.** In `modules/nixos/default.nix`, after the line `./mixins/onepassword.nix`, add:

```nix
      ./mixins/syncthing.nix
```

- [ ] **Step 3: Enable on both hosts.** In `systems/g815/default.nix` (near the other `kyan.*` flags) and in `systems/e1504g/default.nix` (after `kyan.profiles.desktop.enable = true;`), add:

```nix
  # Syncthing mesh: wallpapers + Zen profile, macbook as hub
  # (modules/nixos/mixins/syncthing.nix; spec 2026-07-22).
  kyan.syncthing.enable = true;
```

- [ ] **Step 4: Verify eval.** Run:

```bash
git add modules/nixos/mixins/syncthing.nix modules/nixos/default.nix systems/g815/default.nix systems/e1504g/default.nix
nix eval '.#nixosConfigurations.g815.config.services.syncthing.settings.folders.wallpapers.path'
nix eval '.#nixosConfigurations.e1504g.config.services.syncthing.settings.folders.zen-profile.path'
```

Expected: `"/home/kyandesutter/Pictures/Wallpapers"` and `"/home/kyandesutter/.config/zen/default"`. Fix eval errors before proceeding.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(nixos): syncthing mesh for wallpapers and the zen profile" -- modules/nixos/mixins/syncthing.nix modules/nixos/default.nix systems/g815/default.nix systems/e1504g/default.nix
```

---

### Task 3: `.stignore` activation fragment in zen.nix

**Files:**
- Modify: `users/kyandesutter/mixins/zen.nix` (append to `programs.zen-browser.activationFragments.default`, before the existing priority-90 fragment in the list)

**Interfaces:**
- Consumes: `config.programs.zen-browser.profilesPath` (= `~/.config/zen`), `pkgs.jq`.
- Produces: `~/.config/zen/default/.stignore` maintained on every activation (identical content to the manual seeds in Tasks 5–6; `.stignore` is per-device and never syncs).

- [ ] **Step 1: Add the fragment.** In `users/kyandesutter/mixins/zen.nix`, inside the `programs.zen-browser.activationFragments.default` list, add as the FIRST element (before the priority-90 "mod repair" entry):

```nix
    # Syncthing ignore rules for the zen-profile folder (mixins/syncthing.nix,
    # NixOS-side): keep locks, crash/telemetry state and — the point — all of
    # 1Password's per-machine storage out of sync. 1Password's storage dir is
    # keyed by the profile's internal extension uuid (prefs.js,
    # extensions.webextensions.uuids), so it's resolved here at activation
    # time; on a fresh profile prefs.js doesn't exist yet and the line is
    # simply omitted (there is no 1Password state to leak yet either — the
    # next activation after first launch adds it). The `?` glob stands in for
    # the literal braces in the addon id: Syncthing's pattern language treats
    # braces specially, `?` matches any single character.
    {
      priority = 15;
      requiresLock = true;
      skipSubject = "syncthing stignore";
      text = ''
        profileDir="${config.programs.zen-browser.profilesPath}/default"
        mkdir -p "$profileDir"
        onePassUuid=""
        if [ -f "$profileDir/prefs.js" ]; then
          onePassUuid="$(sed -n 's/^user_pref("extensions\.webextensions\.uuids", "\(.*\)");$/\1/p' "$profileDir/prefs.js" \
            | sed 's/\\"/"/g' \
            | ${lib.getExe pkgs.jq} -r '."{d634138d-c276-4fc8-924b-40a0ea21d284}" // empty' || true)"
        fi
        {
          echo "(?d)lock"
          echo "(?d).parentlock"
          echo "(?d)/crashes"
          echo "(?d)/minidumps"
          echo "/datareporting"
          echo "/saved-telemetry-pings"
          echo "/browser-extension-data/?d634138d-c276-4fc8-924b-40a0ea21d284?"
          if [ -n "$onePassUuid" ]; then
            echo "/storage/default/moz-extension+++$onePassUuid*"
          fi
        } > "$profileDir/.stignore"
      '';
    }
```

- [ ] **Step 2: Verify eval and syntax**

```bash
nix-instantiate --parse users/kyandesutter/mixins/zen.nix >/dev/null && echo parse-ok
git add users/kyandesutter/mixins/zen.nix
nix eval '.#nixosConfigurations.g815.config.system.stateVersion'
```

Expected: `parse-ok` then `"25.11"`-style output with no eval errors.

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(zen): render syncthing stignore excluding 1password storage" -- users/kyandesutter/mixins/zen.nix
```

---

### Task 4: Wallpaper Engine guard for scenes that don't exist locally

**Files:**
- Modify: `users/kyandesutter/mixins/wallpaper-engine.nix` (`build()` in `wallpaperEngineReconcile`, around line 150)

**Interfaces:**
- Consumes: existing `workshop` nix let-binding (`$HOME/.steam/steam/steamapps/workshop/content/431960`).
- Produces: reconciler that no-ops when the selected scene id has no workshop dir (e1504g has no Steam; synced `we-*.png` stills would otherwise make the engine flap on the ~10 s watchdog).

- [ ] **Step 1: Add the guard.** In `users/kyandesutter/mixins/wallpaper-engine.nix`, in `build()`, directly after the line `[[ -n "$id" ]] || return 0`, add:

```bash
        # A synced we-<id>.png still can select a scene this machine doesn't
        # have installed (no Steam on the e1504g) — the still stays the
        # wallpaper, only the live engine is skipped.
        [[ -d "${workshop}/$id" ]] || return 0
```

(That is a nix-interpolated `${workshop}` — it lands in the script as `$HOME/.steam/...`.)

- [ ] **Step 2: Verify**

```bash
nix-instantiate --parse users/kyandesutter/mixins/wallpaper-engine.nix >/dev/null && echo parse-ok
git add users/kyandesutter/mixins/wallpaper-engine.nix
nix eval '.#nixosConfigurations.g815.config.system.stateVersion'
```

Expected: `parse-ok`, clean eval.

- [ ] **Step 3: Commit**

```bash
git commit -m "fix(wallpaper-engine): skip scenes with no local workshop dir" -- users/kyandesutter/mixins/wallpaper-engine.nix
```

---

### Task 5: e1504g first-sync prep and rebuild (BEFORE g815's syncthing exists)

**Files:** none (operational, all over `ssh e1504g`). Run while NO other peer is up: g815 has not been rebuilt yet, the mac's folders are not configured yet — so nothing can sync e1504g's transient state.

**Interfaces:**
- Consumes: Task 2's committed config (e1504g builds from the pushed/local repo — its builds offload to the g815 builder, or fall back to local).
- Produces: e1504g with syncthing running, its `zen-profile` folder EMPTY-INDEXED (no skeleton files, no deletion records), 1Password storage saved at `~/zen-1pass-backup/` with `old-uuid.txt`.

- [ ] **Step 1: Quit Zen and back up 1Password storage on e1504g**

```bash
ssh e1504g '
  set -e
  pkill -x zen || true; sleep 2
  prof="$HOME/.config/zen/default"
  mkdir -p "$HOME/zen-1pass-backup"
  if [ -f "$prof/prefs.js" ]; then
    uuid="$(sed -n "s/^user_pref(\"extensions.webextensions.uuids\", \"\(.*\)\");\$/\1/p" "$prof/prefs.js" \
      | sed "s/\\\\\"/\"/g" \
      | nix shell nixpkgs#jq -c jq -r ".\"{d634138d-c276-4fc8-924b-40a0ea21d284}\" // empty")
    echo "$uuid" > "$HOME/zen-1pass-backup/old-uuid.txt"
    if [ -n "$uuid" ]; then
      cp -a "$prof/storage/default/moz-extension+++$uuid"* "$HOME/zen-1pass-backup/" 2>/dev/null || echo "no 1pass storage dirs found"
    fi
  fi
  ls -la "$HOME/zen-1pass-backup"
'
```

Expected: at least `old-uuid.txt` with a uuid, plus one or more `moz-extension+++...` dirs. If the uuid is empty or no dirs exist, 1Password was never signed in on e1504g — note it, Task 8's restore becomes a plain re-login, continue.

- [ ] **Step 2: Wipe the e1504g Zen profile**

```bash
ssh e1504g 'rm -rf "$HOME/.config/zen/default" && mkdir -p "$HOME/.config/zen/default" && ls -la "$HOME/.config/zen/default"'
```

Expected: empty directory.

- [ ] **Step 3: Sync the repo to e1504g and rebuild it.** The repo must reach e1504g; push and pull (or rsync the working tree if not pushing yet):

```bash
git push
ssh e1504g 'cd ~/.config/nix && git pull && sudo nixos-rebuild switch --flake .#e1504g'
```

Expected: rebuild succeeds (sudo is passwordless on e1504g). Home-manager activation recreates a small Zen skeleton (chrome/ symlinks, containers.json, zen-sessions.jsonlz4, `.stignore` — no prefs.js, so no uuid line yet) and `syncthing.service` starts. No peers exist yet, so nothing propagates.

- [ ] **Step 4: Reset the zen-profile folder to empty (kill skeleton + index)**

```bash
ssh e1504g '
  set -e
  sudo systemctl stop syncthing
  prof="$HOME/.config/zen/default"
  find "$prof" -mindepth 1 -maxdepth 1 ! -name ".stignore" ! -name ".stfolder" -exec rm -rf {} +
  mkdir -p "$prof/.stfolder"
  rm -rf "$HOME/.config/syncthing/index-"*
  sudo systemctl start syncthing
  sleep 5; systemctl is-active syncthing; ls -a "$prof"
'
```

Expected: `active`; the profile contains only `.stignore` and `.stfolder`. (Index removal forces a from-disk rescan of the now-empty dir, so e1504g holds neither skeleton files nor deletion records — g815's state will flow in unopposed in Task 6.) If no `index-*` dir existed (Syncthing v2 stores its DB elsewhere), find it with `ssh e1504g 'ls ~/.config/syncthing'` and remove the database dir(s) (`index-*`/`*.db`) instead — the point is dropping the folder index while stopped.

---

### Task 6: g815 seed — stignore, rebuild, first laptop↔laptop sync

**Files:** none (operational, local on g815).

**Interfaces:**
- Consumes: Tasks 2–4 committed; Task 5 completed (e1504g waiting empty).
- Produces: g815 syncthing running with its real profile indexed; e1504g holding a replica of g815's Zen profile and wallpapers.

- [ ] **Step 1: Quit Zen on g815 and seed `.stignore` manually** (must exist before syncthing's first scan; the activation fragment takes over maintenance afterwards)

```bash
pkill -x zen || true; sleep 2
prof="$HOME/.config/zen/default"
uuid="$(sed -n 's/^user_pref("extensions\.webextensions\.uuids", "\(.*\)");$/\1/p' "$prof/prefs.js" \
  | sed 's/\\"/"/g' | nix shell nixpkgs#jq -c jq -r '."{d634138d-c276-4fc8-924b-40a0ea21d284}" // empty')"
[ -n "$uuid" ] || { echo "NO 1PASSWORD UUID FOUND — stop and investigate"; false; }
cat > "$prof/.stignore" <<EOF
(?d)lock
(?d).parentlock
(?d)/crashes
(?d)/minidumps
/datareporting
/saved-telemetry-pings
/browser-extension-data/?d634138d-c276-4fc8-924b-40a0ea21d284?
/storage/default/moz-extension+++$uuid*
EOF
cat "$prof/.stignore"
```

Expected: 8 lines, last one containing a real uuid. Record that uuid as `SHARED_1PASS_UUID` — after sync it is the uuid on BOTH laptops (prefs.js syncs).

- [ ] **Step 2: Rebuild g815.** Needs sudo — if the prompt blocks, hand to the owner: `! just r`.

```bash
git add -A . && just r
```

Expected: rebuild succeeds; `systemctl is-active syncthing` → `active`.

- [ ] **Step 3: Watch the first sync complete.** The laptops connect directly (mesh). Query g815's API:

```bash
API="$(sed -n 's:.*<apikey>\(.*\)</apikey>.*:\1:p' "$HOME/.config/syncthing/config.xml")"
curl -s -H "X-API-Key: $API" "http://127.0.0.1:8384/rest/system/connections" | nix shell nixpkgs#jq -c jq '.connections | map_values(.connected)'
watch -n 10 "curl -s -H 'X-API-Key: $API' 'http://127.0.0.1:8384/rest/db/completion?folder=zen-profile' | jq .completion"
```

Expected: e1504g's device shows `connected: true`; completion reaches `100` for both `zen-profile` and `wallpapers` (165 MB + 114 MB over LAN — minutes, not hours). Then spot-check on e1504g:

```bash
ssh e1504g 'ls "$HOME/.config/zen/default" | head; ls "$HOME/Pictures/Wallpapers/dark" | head; test -f "$HOME/.config/zen/default/prefs.js" && echo prefs-synced'
```

Expected: a full profile listing, g815's wallpaper files, `prefs-synced`. Also confirm no 1Password storage leaked: `ssh e1504g 'ls "$HOME/.config/zen/default/storage/default" | grep -c moz-extension'` should be ≥1 but `grep` for the `SHARED_1PASS_UUID` must find nothing.

- [ ] **Step 4: Check for conflict files (should be none)**

```bash
ssh e1504g 'find "$HOME/.config/zen/default" -name "*sync-conflict*"'
find "$HOME/.config/zen/default" -name "*sync-conflict*"
```

Expected: no output. If conflicts exist on g815's side, e1504g skeleton won somewhere — resolve by keeping the non-conflict g815 copy (`mv` the conflict file over the winner if the winner is the skeleton version, judged by size/content) and re-check.

---

### Task 7: Configure the mac hub over its REST API

**Files:** none (operational, over `ssh macbook`).

**Interfaces:**
- Consumes: Task 1's IDs; laptops running (Task 6).
- Produces: mac replicating both folders (`~/Pictures/Wallpapers`, `~/Sync/zen-profile`), completing the store-and-forward hub.

- [ ] **Step 1: Create the replica dirs and add devices + folders.** Substitute the three real IDs from Task 1:

```bash
ssh macbook '
  set -e
  mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/Sync/zen-profile"
  CFG="$HOME/Library/Application Support/Syncthing/config.xml"
  API="$(sed -n "s:.*<apikey>\(.*\)</apikey>.*:\1:p" "$CFG")"
  ST="http://127.0.0.1:8384/rest"
  H="X-API-Key: $API"
  curl -sf -H "$H" -X PUT "$ST/config/devices/@G815_ID@"   -d "{\"deviceID\":\"@G815_ID@\",\"name\":\"g815\",\"addresses\":[\"tcp://100.114.32.78:22000\",\"tcp://192.168.86.95:22000\"]}"
  curl -sf -H "$H" -X PUT "$ST/config/devices/@E1504G_ID@" -d "{\"deviceID\":\"@E1504G_ID@\",\"name\":\"e1504g\",\"addresses\":[\"tcp://100.109.196.64:22000\",\"tcp://192.168.86.116:22000\"]}"
  curl -sf -H "$H" -X PUT "$ST/config/folders/wallpapers"  -d "{\"id\":\"wallpapers\",\"label\":\"wallpapers\",\"path\":\"$HOME/Pictures/Wallpapers\",\"type\":\"sendreceive\",\"devices\":[{\"deviceID\":\"@G815_ID@\"},{\"deviceID\":\"@E1504G_ID@\"},{\"deviceID\":\"@MAC_ID@\"}]}"
  curl -sf -H "$H" -X PUT "$ST/config/folders/zen-profile" -d "{\"id\":\"zen-profile\",\"label\":\"zen-profile\",\"path\":\"$HOME/Sync/zen-profile\",\"type\":\"sendreceive\",\"devices\":[{\"deviceID\":\"@G815_ID@\"},{\"deviceID\":\"@E1504G_ID@\"},{\"deviceID\":\"@MAC_ID@\"}]}"
  curl -s -H "$H" "$ST/config/restart-required"
'
```

Expected: no curl errors; final call returns `{"requiresRestart":false}` (v1.x may return `true` — then `curl -s -H "$H" -X POST "$ST/system/restart"`).

- [ ] **Step 2: Verify the hub replicates**

```bash
ssh macbook '
  CFG="$HOME/Library/Application Support/Syncthing/config.xml"
  API="$(sed -n "s:.*<apikey>\(.*\)</apikey>.*:\1:p" "$CFG")"
  curl -s -H "X-API-Key: $API" "http://127.0.0.1:8384/rest/db/completion?folder=zen-profile"
  ls "$HOME/Pictures/Wallpapers" "$HOME/Sync/zen-profile" | head -20
'
```

Expected: completion trending to 100; both dirs filling with the laptops' content. Confirm no 1Password dir ever lands on the mac: `ssh macbook 'ls "$HOME/Sync/zen-profile/storage/default" | grep <SHARED_1PASS_UUID>'` → no output.

---

### Task 8: Restore 1Password on e1504g and verify end-to-end

**Files:** none (operational, over `ssh e1504g`).

**Interfaces:**
- Consumes: `~/zen-1pass-backup/` + `old-uuid.txt` (Task 5), synced `prefs.js` (Task 6), `SHARED_1PASS_UUID` (Task 6 Step 1).
- Produces: e1504g Zen running with g815's tabs/spaces/extension settings and (best-effort) its own preserved 1Password login.

- [ ] **Step 1: Ensure the ignore line exists on e1504g BEFORE moving the dir in** (the activation fragment only re-renders at the next rebuild; without the line the restored dir would sync out)

```bash
ssh e1504g '
  grep -q "moz-extension+++" "$HOME/.config/zen/default/.stignore" \
    || echo "/storage/default/moz-extension+++'"$SHARED_1PASS_UUID"'*" >> "$HOME/.config/zen/default/.stignore"
  cat "$HOME/.config/zen/default/.stignore"
'
```

Expected: the uuid line present exactly once, with the g815-synced (= now shared) uuid.

- [ ] **Step 2: Move the backup in under the shared uuid and fix its identity.** QuotaManager regenerates missing `.metadata-v2` from the directory name; the IndexedDB sqlite embeds the origin in its `database` table and gets updated directly. Skip this step entirely (and just re-login) if Task 5 found no backup.

```bash
ssh e1504g '
  set -e
  old="$(cat "$HOME/zen-1pass-backup/old-uuid.txt")"
  new="'"$SHARED_1PASS_UUID"'"
  cd "$HOME/zen-1pass-backup"
  for d in moz-extension+++"$old"*; do
    [ -e "$d" ] || continue
    tgt="$HOME/.config/zen/default/storage/default/${d/$old/$new}"
    rm -rf "$tgt"
    cp -a "$d" "$tgt"
    rm -f "$tgt/.metadata" "$tgt/.metadata-v2"
    for db in "$tgt"/idb/*.sqlite; do
      [ -e "$db" ] || continue
      nix shell nixpkgs#sqlite -c sqlite3 "$db" "UPDATE database SET origin=replace(origin, \"$old\", \"$new\");" || true
    done
  done
  ls "$HOME/.config/zen/default/storage/default/" | grep "$new"
'
```

Expected: the moved dir(s) listed under the new uuid. The `|| true` on sqlite is deliberate: a schema without that table just means QuotaManager decides — the fallback is the re-login, not a failed task.

- [ ] **Step 3: First Zen launch on e1504g + verification.** Zen must be CLOSED on g815 (one browser at a time). Ask the owner (or do over ssh with a display: `ssh e1504g 'systemd-run --user --scope zen-beta'` won't attach to the session — the owner should open Zen from the e1504g desktop). Verify with the owner or over ssh:
  - Tabs and spaces match g815's last session (Personal/CanaryCoders/KangaCoders spaces present, tab set restored).
  - Extension settings carried over (e.g. Enhancer for YouTube options match).
  - 1Password: still signed in → done. Asks to sign in → the origin surgery didn't survive; sign in once (desktop app is on e1504g) and note it. Either way, remove the backup: `ssh e1504g 'rm -rf "$HOME/zen-1pass-backup"'` — only after 1Password works.

- [ ] **Step 4: Wallpaper round-trip test.** On g815, pick a different wallpaper via DMS (or `dms ipc call wallpaper set <path>`); within a minute:

```bash
ssh e1504g 'ls -t "$HOME/Pictures/Wallpapers/dark" | head -3'
ssh macbook 'ls -t "$HOME/Pictures/Wallpapers/dark" | head -3'
```

Expected: any newly added file appears on both. On e1504g, additionally pick a synced `we-*.png` still in DMS and confirm `systemctl --user status wallpaper-engine` shows no restart-flapping (Task 4's guard).

- [ ] **Step 5: Close Zen on e1504g, reopen on g815** — confirm the reverse direction: e1504g's session changes (e.g. one new tab opened during Step 3) appear on g815 after sync settles.

- [ ] **Step 6: Final commit + push**

```bash
git status --short   # expect only untracked/unrelated noise, no plan-file changes
git push
```

Then the owner (or a later session) pulls on the mac per the standard sync flow — no mac rebuild is needed (no darwin config changed).

---

## Self-review notes

- Spec coverage: mixin (Task 2), stignore/1Password exclusion (Task 3), WE guard (Task 4), first-sync seeding g815 + e1504g wipe preserving 1Password (Tasks 5, 6, 8), mac hub (Task 7), verification (Tasks 6–8). Out-of-scope items untouched.
- The empty-index reset in Task 5 Step 4 is what makes "g815 wins" deterministic — do not reorder Tasks 5 and 6.
- `SHARED_1PASS_UUID` is defined in Task 6 Step 1 and consumed in Tasks 7–8.
