# iPhone ↔ g815 (Linux) integration over Tailscale — design

**Date:** 2026-06-21
**Host:** g815 (`x86_64-linux`, NixOS, Hyprland + Noctalia)
**Status:** approved, pending implementation

## Goal

Wire up phone↔desktop integration between the user's iPhone and the g815 laptop,
covering two capabilities:

1. **KDE Connect-style integration** — phone notification mirroring, shared
   clipboard, media control, find-my-phone.
2. **AirDrop-style file/link sharing** — on-demand transfer both directions.

Both must work on the same physical Wi-Fi (primary path, LAN auto-discovery) and
keep working when the two devices are apart, over Tailscale (backup path). The two
devices are always members of the same tailnet.

**Non-goals:**
- Remote input (using the phone as a trackpad/keyboard to drive the desktop). KDE
  Connect ships this as a plugin; we neither configure nor verify it. It can be
  ignored or toggled off in the app.
- Background folder sync (Syncthing) — explicitly out of scope.
- SSH/remote shell from the phone — out of scope.

## Tools

| Capability                       | Tool          | iOS app | NixOS option                | Ports (auto-opened)   |
| -------------------------------- | ------------- | ------- | --------------------------- | --------------------- |
| Notifications/clipboard/media/FMP | KDE Connect   | native  | `programs.kdeconnect.enable` | TCP+UDP `1714–1764`   |
| AirDrop-style file/link sharing  | LocalSend     | native  | `programs.localsend.enable`  | TCP+UDP `53317`       |

Both NixOS modules open their LAN firewall ports themselves; we do not hand-roll
port lists.

## Network model

- **Same Wi-Fi (primary):** KDE Connect and LocalSend both discover peers via LAN
  broadcast/multicast. Auto-discovery works, zero manual config.
- **Apart (Tailscale backup):** broadcast/multicast does **not** traverse the
  tailnet (Tailscale is a point-to-point overlay with no broadcast). So:
  - The g815 is reached by its **stable Tailscale IP / MagicDNS name** (`100.x` /
    `g815.<tailnet>.ts.net`). Pair once by IP; the address is stable so it is
    permanent.
  - The firewall must not drop this traffic, so `tailscale0` is added to
    `networking.firewall.trustedInterfaces`.

This is the "slightly more open firewall" trade accepted during design: standard
ports open on the LAN **and** the whole Tailscale interface trusted. Tailscale
traffic is already authenticated end-to-end, so trusting `tailscale0` is the
conventional hardening posture.

## Architecture / file changes

### 1. New system mixin — `modules/nixos/mixins/phone-integration.nix`

Self-contained, one concern (phone integration). Gated internally on
`config.kyan.desktop.enable` (same import-unconditionally / gate-internally pattern
as `hyprland.nix`), so it is a no-op on any future non-desktop NixOS host.

```nix
{ config, lib, ... }:
lib.mkIf config.kyan.desktop.enable {
  programs.kdeconnect.enable = true;   # opens 1714–1764
  programs.localsend.enable  = true;   # opens 53317
  networking.firewall.trustedInterfaces = [ "tailscale0" ];  # Tailscale backup path
}
```

(`trustedInterfaces` is a list and merges additively with any other module that
sets it, so this does not conflict with `networking.nix`.)

Imported by adding one line to `modules/nixos/default.nix`'s `imports`.

**Why here, not in `tailscale.nix`:** `tailscale0` trust is only wanted as part of
this feature; putting it in the shared `tailscale.nix` would require a Linux guard
and split the feature across two files. Keeping it in the one mixin makes the whole
feature self-contained and trivially reversible.

### 2. Autostart — `users/kyandesutter/mixins/autostart.nix`

Two new `systemd.user.services`, following the file's existing DE-agnostic pattern:
`PartOf=/After=graphical-session.target`, `WantedBy=graphical-session.target`,
**no `Restart=`** (closing the app must not relaunch it), bare command names
resolved from the imported graphical-session env.

- **`kdeconnect-indicator`** — starts the tray indicator, which spawns
  `kdeconnectd` (the daemon). Surfaces in Noctalia's system tray.
- **`localsend`** — runs the receiver so files can arrive without manually opening
  the app. LocalSend opens a window at launch; "launch minimized / minimize to
  tray" is toggled in-app (no reliable CLI flag), documented as a post-rebuild
  step.

The `kdeconnect` and `localsend` binaries come from the system-level `programs.*`
above (installed into the system profile, on PATH for the user services).

## Data flow

- **Notifications:** KDE Connect daemon receives phone notifications → calls the
  freedesktop `org.freedesktop.Notifications` D-Bus API → Noctalia's notification
  daemon renders them. No conflict with the existing notification stack.
- **Clipboard:** KDE Connect syncs via the Wayland selection. Coexists with the
  existing `wl-clip-persist` + Noctalia ClipboardService poller (they own the
  *regular* selection lifecycle; KDE Connect reads/writes it like any client).
- **File transfer:** LocalSend HTTP(S) on `53317`, peer found by LAN multicast or
  manual Tailscale-IP favorite.

## Pairing / first-run (manual, owner steps after rebuild)

1. Rebuild (owner only).
2. On iPhone: install **KDE Connect** and **LocalSend** from the App Store.
3. On the same Wi-Fi: both apps auto-discover the g815. Pair KDE Connect (accept
   on the desktop tray). Send a test file with LocalSend.
4. For the Tailscale path: in each iOS app, add the g815 by its Tailscale IP /
   MagicDNS name (KDE Connect: "Add device by IP"; LocalSend: favorite by IP).
   Verify by disconnecting from Wi-Fi (cellular) and re-testing.
5. In LocalSend, enable "launch minimized / minimize to tray" if desired.

## Known caveats

- **LocalSend at login** opens a window until "launch minimized" is set in-app.
- **Tailscale discovery is manual** by design (no broadcast across the tailnet);
  the stable `100.x` address makes the one-time add-by-IP permanent.

## Verification (non-building checks only — owner runs the rebuild)

- `nix-instantiate --parse modules/nixos/mixins/phone-integration.nix` — syntax.
- `nix eval '.#nixosConfigurations.g815.config.system.stateVersion'` — forces all
  module imports (including the new mixin) to resolve without building.
- `git add` the new/changed files (the flake only sees git-tracked files); then
  **stop** — the owner runs the rebuild.

## Rebuild policy

Per repo rules: Claude does **not** run any `nixos-rebuild` / `home-manager switch`
/ `just` build or switch recipe. Changes are staged with `git add`, documented, and
left for the owner to rebuild manually.
