# librepods AirPods integration (g815)

**Date:** 2026-07-02
**Host:** g815 (NixOS). macOS handles AirPods natively — no macbook change, so
this feature is intentionally **g815-only** and carries no cross-host sync
obligation.

## Goal

Get AirPods control (noise modes, battery, ear-detection, etc.) on the g815
desktop via librepods, surfaced through **librepods' own Qt system-tray app**,
which Noctalia's `tray` widget already hosts.

## Decision: use the native tray app, not a custom Noctalia widget

An earlier iteration built a Noctalia `custom_button` bar widget that drove
`librepods-ctl` noise modes. It was dropped: librepods **ships a full Qt
system-tray app by default**, and Noctalia's `tray` widget renders any
StatusNotifierItem — so the librepods tray icon already gives noise control,
battery, and settings. A separate bar button is redundant, and (see Constraints)
it could only ever *set* noise modes with no state/battery readout anyway.

So the integration reduces to: **install librepods and autostart it** so its
tray icon is present at login.

## Constraints — ground truth from source (why the native app wins)

The nixpkgs `librepods` package is **v0.2.5**, the Qt tray app (NOT the
unreleased Rust rewrite whose `org.librepods.Daemon` D-Bus interface appears in
web results). Verified against the v0.2.5 source:

- **`librepods-ctl` is fire-and-forget** (`linux/librepods-ctl.cpp`): it writes
  `argv[1]` to the `app_server` `QLocalSocket` and reads nothing back.
- The socket handler (`linux/main.cpp`) accepts only `reopen`, `noise:off`,
  `noise:anc`, `noise:transparency`, `noise:adaptive`.
- **Battery / ANC-mode / ear-detection / connection status are NOT exported** to
  D-Bus, BlueZ, UPower, a file, or the socket — they live only inside the Qt UI
  (`linux/battery.hpp`). So any external bar widget could show no state; the
  app's own tray UI is the only place this data is visible.
- Noctalia V5's `custom_button` widget is static (no `textCommand`), confirming a
  bar widget couldn't display live AirPods state.

The `cysgodi/librepods` repo the owner found is a near-mirror of upstream,
*behind* the v0.2.5 tag; it offers nothing over nixpkgs v0.2.5.

## Design

Mirrors the existing per-app pattern (e.g. `beeper.nix` for the package +
`autostart.nix` for the login service):

1. **`users/kyandesutter/mixins/airpods.nix`** (new) — `home.packages = [
   pkgs.librepods ]`. A one-concern topical package mixin, imported from
   `linux.nix`.
2. **`users/kyandesutter/mixins/autostart.nix`** — a `systemd.user.service`
   `librepods`, bound to `graphical-session.target` (`X-SwitchMethod =
   "keep-old"`, no `Restart`), `ExecStart = ${pkgs.librepods}/bin/librepods
   --hide`. Starts hidden to the tray; the icon is picked up by Noctalia's `tray`
   widget. Same shape as the other DE-agnostic login apps in that file.

No Noctalia changes. No wrapper script. No enable flag (always-on where
imported).

## Prerequisites (already satisfied)

- AirPods paired over BlueZ (owner confirms done).
- `hardware.bluetooth.settings.General.Experimental = true` — already set in
  `modules/nixos/mixins/bluetooth.nix` (needed for the AAP L2CAP channel).

## Verification

1. `nix-instantiate --parse` on `airpods.nix` + `autostart.nix`.
2. `nixos-rebuild build --flake .#g815` (no sudo) — full eval succeeds.
3. After a switch + relogin: `systemctl --user status librepods` is
   `active (running)`, and the librepods tray icon appears in the Noctalia bar's
   tray, offering noise control + battery.

## Out of scope

A bar widget showing live battery / current mode — impossible with v0.2.5's
write-only, no-readback surface without patching librepods or packaging the
unreleased Rust rewrite. The native tray app covers the actual need.
