# Syncthing hub: shared wallpapers + Zen profile sync (2026-07-22)

## Goal

Keep the two Linux laptops (g815, e1504g) in sync, with the always-on macbook
as the store-and-forward hub, for:

1. **Wallpapers** — the same `~/Pictures/Wallpapers` collection everywhere,
   including Wallpaper Engine stills added at runtime.
2. **Zen browser** — tabs, spaces, and extension settings follow the user from
   one laptop to the other. 1Password state is explicitly NOT synced (its
   pairing/login is per-machine).

The mac is a relay only: it stores replicas so either laptop can sync while the
other is off. Its own desktop wallpaper is untouched and Zen is not installed
there.

## Decisions (user-confirmed)

- Mechanism: **Syncthing** (the mac already ships the `syncthing-app` cask).
- Mac role: **relay only**.
- Zen concurrency model: **one browser at a time**; last-closed wins.
- Zen sync mode: **direct live-profile sync** of `~/.config/zen/default` with
  ignore patterns (no staging dir, no launch wrapper).
- First sync: **g815 seeds everything**; e1504g's Zen profile is wiped first,
  preserving only its 1Password login state.

## Topology

Three devices, full mesh (each knows both others); the mac's always-on-ness is
what makes it the effective hub. Connections go over tailscale IPs with
home-LAN fallback addresses, mirroring the ssh / remote-builder precedent
(`systems/e1504g/default.nix`).

Two folders:

| Folder id     | g815 / e1504g path      | macbook path        |
| ------------- | ----------------------- | ------------------- |
| `wallpapers`  | `~/Pictures/Wallpapers` | `~/Pictures/Wallpapers` (passive replica) |
| `zen-profile` | `~/.config/zen/default` | `~/Sync/zen-profile` (passive replica) |

## Components

### `modules/nixos/mixins/syncthing.nix` (new)

- `options.kyan.syncthing.enable = lib.mkEnableOption …`, gated with
  `lib.mkIf`; enabled from both `systems/g815/default.nix` and
  `systems/e1504g/default.nix`.
- System `services.syncthing` running as `kyandesutter`, GUI on
  `127.0.0.1:8384`.
- Declarative `settings.devices` (three device IDs hardcoded once collected)
  and `settings.folders` (the two folders above). Device `addresses` pin the
  tailscale IP first, home-LAN IP second.
- Keys/certs are runtime-generated on first start (not agenix-managed); a
  machine reinstall means updating that one device ID in the mixin.
- Firewall: sync traffic arrives over tailscale or the home LAN; open the
  sync port for LAN the same way ssh's LAN fallback does. Global discovery /
  relays are unnecessary (addresses are pinned) and stay disabled.

### Zen ignore rules (`users/kyandesutter/mixins/zen.nix`)

A home-manager activation step renders `.stignore` into the profile root on
both laptops (`.stignore` is per-device by design and never syncs). Excluded:

- `lock`, `.parentlock` (runtime lock symlinks),
- crash/telemetry state: `crashes/`, `minidumps/`, `datareporting/`,
  `saved-telemetry-pings/`,
- **1Password**: `storage/default/moz-extension+++<uuid>*` where the uuid is
  resolved from `prefs.js` (`extensions.webextensions.uuids`, addon id
  `{d634138d-c276-4fc8-924b-40a0ea21d284}`) at activation time, plus
  `browser-extension-data/{d634138d-c276-4fc8-924b-40a0ea21d284}` defensively
  (that layout doesn't currently exist but older storage code can create it).

Everything else syncs: `sessionstore*` (tabs), `zen-sessions.jsonlz4`
(spaces), the other `storage/default/moz-extension+++*` dirs (extension
settings), `prefs.js` (which also unifies the extension-uuid map across
machines — required for the storage dirs to resolve), cookies, history,
`chrome/` (HM-managed store symlinks resolve identically on both hosts since
both build from the same flake).

Known imperfection: `storage-sync-v2.sqlite` holds every extension's
`storage.sync` in one file and can't be split per-extension, so any 1Password
`storage.sync` crumbs ride along. 1Password's real state is in its excluded
local storage, so this is cosmetic.

### Mac configuration

`syncthing-app` (homebrew cask) is configured during implementation over SSH
via Syncthing's REST API where possible — add the two laptop devices, accept
both folders at the paths above, confirm it launches at login. Anything the
API can't reach is a one-time manual accept in its GUI by the owner.

### Wallpaper Engine guard (`users/kyandesutter/mixins/wallpaper-engine.nix`)

The reconciler's `build()` gains a guard: if the selected scene id has no
workshop dir (`~/.steam/steam/steamapps/workshop/content/431960/<id>`), skip
launching. Without it, picking a synced `we-*.png` on e1504g (no Steam) makes
the engine flap on the ~10 s watchdog whenever on AC. The still remains the
wallpaper either way; only the live engine is skipped.

## First sync (implementation-time procedure)

1. Enable Syncthing on g815 and e1504g (rebuild both), collect the three
   device IDs, pin them in the mixin, rebuild again.
2. On e1504g, before its `zen-profile` folder first connects: quit Zen, move
   the 1Password `moz-extension+++<uuid>` storage dir aside, delete
   `~/.config/zen/default`'s contents, let g815's state replicate.
3. Restore the saved 1Password dir under the uuid the synced `prefs.js` maps
   1Password to, patching the origin inside the dir's `.metadata-v2` to match.
   If 1Password still drops the session (its storage is origin-keyed and the
   rename may not survive quota-manager validation), it's a one-time re-login
   on e1504g — surfaced, not silently broken.
4. Wallpapers folder needs no seeding ceremony: e1504g and the mac start
   empty or near-empty and converge to g815's set.

## Constraints and failure modes

- **One browser at a time.** Opening Zen on laptop B while it's open on A and
  mid-sync can replicate torn sqlite state. Confirmed usage is sequential;
  the last-closed browser's state wins.
- Zen must still be closed during `home-manager switch`es that touch spaces or
  containers (pre-existing constraint, unchanged).
- Offline divergence leaves `*.sync-conflict*` files to resolve by hand;
  expected to be rare with the mac always reachable over tailscale.
- The mac must be running Syncthing for hub semantics; if it's down, the two
  laptops still sync directly when both are on (full mesh).

## Verification

- Pick a wallpaper on g815 → the file appears in e1504g's
  `~/Pictures/Wallpapers` and DMS picker; same file lands on the mac replica.
- Open tabs / reorder a space on g815, quit Zen, wait for sync → open Zen on
  e1504g: tabs, spaces, and extension settings match.
- 1Password on e1504g: still signed in after the seed (or at worst prompts
  once); no 1Password storage dir present in the mac's `zen-profile` replica.
- `nix eval` of both NixOS hosts' `config.system.stateVersion` still passes.

## Out of scope

- Setting the mac's desktop wallpaper from the synced folder.
- Zen on the mac.
- Merging concurrent sessions (Firefox Sync-style); rejected with the
  mechanism choice.
- The orphaned `users/kyandesutter/wallpapers/` repo dir (untouched).
