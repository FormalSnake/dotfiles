# librepods → Noctalia AirPods control (g815)

**Date:** 2026-07-02
**Host:** g815 (NixOS). macOS handles AirPods natively — no macbook change, so
this feature is intentionally **g815-only** and carries no cross-host sync
obligation.

## Goal

Expose everything librepods can *usefully* drive from the Noctalia bar. In
practice that is **noise-control mode switching**, because that is the entire
scriptable surface of the packaged version (see Constraints).

## Constraints — ground truth from source

The nixpkgs `librepods` package is **v0.2.5**, the old Qt tray app (NOT the
unreleased Rust rewrite whose `org.librepods.Daemon` D-Bus interface appears in
web results). Verified against the v0.2.5 source and the Noctalia build:

- **`librepods-ctl` is fire-and-forget.** It opens the `app_server`
  `QLocalSocket`, writes `argv[1]`, and disconnects — it reads **nothing** back
  (`linux/librepods-ctl.cpp`).
- The daemon's socket handler (`linux/main.cpp` ~L1075) accepts exactly five
  messages: `reopen`, `noise:off`, `noise:anc`, `noise:transparency`,
  `noise:adaptive`. All write-only.
- **Battery / ANC-mode / ear-detection / connection status are NOT exported** —
  no D-Bus service, no BlueZ BatteryProvider, no UPower, no file, not over the
  socket. Battery exists only as a QML property inside the Qt UI
  (`linux/battery.hpp`). The app's only D-Bus use is *consuming* `org.bluez`
  (BlueZ) and MPRIS.
- Noctalia V5's `custom_button` widget is **static**: it parses `glyph`,
  `label`, `tooltip`, `command`, `right_command`, `middle_command`,
  `scroll_up_command`, `scroll_down_command` (verified in
  `src/shell/bar/widgets/custom_button_widget.cpp` + `widget_factory.cpp`, type
  string `"custom_button"`). There is **no** `textCommand`/`textIntervalMs` —
  that was the V4 Quickshell widget. So the bar button cannot poll or display
  live state.

**Therefore:** the widget is a control button; mode feedback is delivered via
`notify-send` (matching the config's existing OSD-style notifications), and
battery/details are reached by right-clicking to open librepods' own window.

The `cysgodi/librepods` repo the owner found is a near-mirror of upstream,
*behind* the v0.2.5 tag (its `linux/` lacks `librepods-ctl.cpp`); its only
Rust artifact is a CI workflow. It offers nothing over nixpkgs v0.2.5, so
nixpkgs `librepods` stays the base.

## Design

Two files touched; no new mixin (the bar is centrally owned by `noctalia.nix`,
and a `writeShellApplication` control wrapper there follows the existing
`auraRepaint` precedent). No enable flag — always-on where imported, per the
"always-on mixins set options directly" convention.

### 1. `users/kyandesutter/mixins/autostart.nix` — the daemon

Add `systemd.user.services.librepods`, bound to `graphical-session.target`,
matching the file's existing DE-agnostic-login-app pattern
(`PartOf`/`After` graphical-session, `X-SwitchMethod = "keep-old"`, **no**
`Restart`). ExecStart uses the absolute store path
`${pkgs.librepods}/bin/librepods --hide` (start hidden to tray; no login-shell
PATH dance needed since it's an absolute path — same as noctalia/easyeffects).
This daemon hosts the `app_server` socket the control wrapper talks to.

### 2. `users/kyandesutter/mixins/noctalia.nix` — wrapper + bar widget

**`librepodsAnc` wrapper** (new entry in the `let` block, a
`writeShellApplication`; `runtimeInputs = [ pkgs.librepods pkgs.libnotify
pkgs.coreutils ]`):

- Modes: `off anc transparency adaptive`, with human labels
  (`Off`, `Noise Cancellation`, `Transparency`, `Adaptive`).
- Current mode tracked in a state file at
  `${XDG_RUNTIME_DIR:-/tmp}/librepods-anc.mode` (index 0–3). No readback is
  possible, so this is optimistic local state; it starts unknown and becomes
  authoritative after the first action.
- Subcommands:
  - `set <off|anc|transparency|adaptive>` — run
    `${pkgs.librepods}/bin/librepods-ctl noise:<m>`; on success persist the
    index and fire an OSD notification; on connect failure (ctl exit 1, daemon
    down) notify "librepods not running".
  - `cycle` — advance `(cur+1) mod 4`, then `set`.
  - `prev` — `(cur+3) mod 4`, then `set`.
- Notifications use `notify-send` with a synchronous-replace hint
  (`-h string:x-canonical-private-synchronous:airpods`) so repeated toggles
  replace rather than stack; app name "AirPods".

**Package:** extend the existing `home.packages` line
(`[ auraRepaint ]`) to `[ auraRepaint librepodsAnc pkgs.librepods ]` — puts the
wrapper plus `librepods`/`librepods-ctl` on PATH.

**Bar:** insert `"airpods"` into `bar.main.end` immediately after `"bluetooth"`.

**Widget table** `widget.airpods`:

```
type          = "custom_button"
glyph         = "headphones"        # tabler glyph
tooltip       = "AirPods noise control — click cycle · scroll adjust · middle transparency · right open"
command       = "${librepodsAnc}/bin/librepods-anc cycle"
scroll_up_command   = "${librepodsAnc}/bin/librepods-anc cycle"
scroll_down_command = "${librepodsAnc}/bin/librepods-anc prev"
middle_command      = "${librepodsAnc}/bin/librepods-anc set transparency"
right_command       = "${pkgs.librepods}/bin/librepods-ctl reopen"
```

| Action | Effect |
|---|---|
| Left click | cycle Off → ANC → Transparency → Adaptive (OSD) |
| Scroll up / down | step mode forward / back |
| Middle click | jump to Transparency ("let me hear") |
| Right click | open the librepods window (where battery is visible) |

## Prerequisites (already satisfied)

- AirPods paired over BlueZ (owner confirms done).
- `hardware.bluetooth.settings.General.Experimental = true` — already set in
  `modules/nixos/mixins/bluetooth.nix`.

## Verification

1. `nix-instantiate --parse` on both edited files.
2. `nixos-rebuild` on g815 — this runs `noctalia config validate` on the new
   `widget.airpods` table (build fails on an invalid key). If sudo blocks the
   rebuild, hand that step to the owner.
3. Runtime smoke test: `systemctl --user status librepods`, then
   `librepods-anc cycle` and confirm the OSD + audible mode change; click the
   bar widget.

## Out of scope

Battery in the bar, current-mode display, ear-detection, etc. — all require
either patching v0.2.5 to export state or packaging the unreleased Rust
rewrite. Owner chose the control-only path.
