# Aura Ambient — per-key screen-reactive keyboard lighting (g815)

**Date:** 2026-07-15
**Host:** g815 (NixOS, niri + Noctalia)
**Status:** design approved, ready for implementation plan

## Goal

Replicate ASUS Aura's "Ambient" mode (Armoury Crate on Windows) on Linux: sample
the screen and drive the keyboard's per-key RGB to match in real time,
Ambilight-style, with a horizontal left-to-right spread across the keyboard that
follows the screen. This *replaces* the wallpaper-accent static color in the one
state where the keyboard currently shows a static color — session up and on AC.

## Feasibility findings (validated on hardware 2026-07-15)

- `asusd`/`asusctl` exposes only **one** real hardware zone for this keyboard
  (zone 0 = whole keyboard). `--zone 1..3` are accepted (`rc=0`) but map to
  logo/lightbar zones this 18" chassis lacks — painting them does nothing. So a
  multi-zone spread is **not** reachable through asusd.
- **OpenRGB detects the keyboard with full per-key control.** `openrgb -l` (run
  as root) reports the N-KEY device (`/dev/hidraw2`) with a **`Direct`** mode
  active and all ~84 keys enumerated individually under `Zones: Keyboard`. Direct
  mode is what enables live per-key streaming — the same layer Armoury Crate uses.
- `python3Packages.openrgb-python` (0.3.6) is packaged in nixpkgs → the
  `OpenRGBClient` SDK is available.
- `pkgs.openrgb` ships udev rules (`60-openrgb.rules`) using `TAG+="uaccess"`.
  Installing them via `services.udev.packages` grants the **logged-in user** (and
  therefore its `systemd --user` services) access to the keyboard's hidraw node
  with **no root and no system-wide OpenRGB server**.
- Capture pipeline works: `niri msg focused-output` yields the active connector;
  `grim -o <connector> -s <scale>` captures a downscaled frame of the main display.

## Architecture

Keyboard **LED color** ownership time-shares between asusd and OpenRGB, gated by
power source. **Brightness** stays entirely asusd's job (the `kbd_backlight`
sysfs node, driven by `kbdDim`/power-tune) — it is orthogonal to per-key color,
so OpenRGB colors simply render at whatever brightness asusd has set.

| Power source | Keyboard color owner | Effect |
|---|---|---|
| **AC** (charging) | **OpenRGB Direct** (ambient daemon) | live per-key screen sample |
| Power bank | asusd (`aura-repaint`) | breathe, theme accent (unchanged) |
| Battery | asusd (`aura-repaint`) | backlight off (unchanged) |

They never write concurrently: `power-tune` serializes the handoff (stop ambient
*before* calling `aura-repaint`, and don't call `aura-repaint` while ambient runs
on AC). asusd stays fully enabled for fans, battery limit, suspend power flags,
and all non-AC keyboard behavior.

### Components

1. **`modules/nixos/mixins/aura-ambient.nix`** (system, g815), gated behind
   `options.kyan.auraAmbient.enable`:
   - `services.udev.packages = [ pkgs.openrgb ]` — installs the uaccess rules so
     the user session can drive the keyboard hidraw node.
   - Does **not** enable `services.hardware.openrgb` (that would run a root server
     holding the device full-time and fight asusd when ambient is off).

2. **The ambient daemon** (home-manager, wired in `users/kyandesutter/`):
   - A wrapper (`writeShellApplication`) that launches `openrgb --server
     --noautoconnect` in the background, waits for its port, runs the Python
     streamer, and kills the server on exit (`trap`).
   - **Streamer** (`python3.withPackages [ openrgb-python pillow ]`, `grim` on
     PATH): connect to the local server, set the keyboard to `Direct` mode, read
     the zone's matrix map to get each key's **column** index. Then loop ~15 Hz:
     - resolve the focused output connector (`niri msg focused-output`, regex the
       `(eDP-1)` connector — jq is not installed);
     - `grim -o <connector> -s <scale> -t ppm -` → Pillow downscale to
       `matrix_width × 1` (box-averaged columns);
     - assign each key its column's color (all rows in a column share the color →
       clean vertical-bar horizontal spread, matching the Windows effect);
     - per-key exponential smoothing to avoid strobing on scene cuts;
     - push the frame (`device.show()`).
     - If `grim` fails (screen locked/DPMS off), skip the frame and keep the last.
   - Runs as a `systemd --user` service `aura-ambient.service`, bound to
     `graphical-session.target` (follows the niri session like the autostart apps).

3. **Lifecycle gating — `power-tune` in `users/kyandesutter/mixins/niri.nix`:**
   In the `reconcile()` source-change branch, when `kyan.auraAmbient.enable`:
   - source is AC → `systemctl --user start aura-ambient.service` (ambient takes
     over color); **skip** the `aura-repaint` static paint.
   - source is non-AC → `systemctl --user stop aura-ambient.service`, then
     `aura-repaint "$colour"` exactly as today (breathe / off).
   When the flag is off, `power-tune` behaves exactly as it does now.

### Screen → keyboard mapping

Horizontal only (the dominant Ambilight effect): keyboard column *c* of
*matrix_width* maps to screen x-fraction `c / (matrix_width-1)`; the screen is
box-averaged into `matrix_width` columns and each key takes its column color. A
2D mapping (keyboard rows → screen rows) is a possible later refinement; out of
scope for v1.

## What is explicitly NOT changed

- **Power management (`power.nix`, dGPU reconciler, PPD ownership)** — untouched.
  This change lives entirely in the session-owned keyboard-color path, which the
  power spec already designates as the session's job.
- **The theme system** (`aura-repaint`, noctalia `aura` template + post_hook,
  boot seed in `asus.nix`, breathe-on-power-bank) — stays intact as the pre-session
  and non-AC color source. Ambient only overrides the AC-lit state.
- **asusd** — stays enabled; still owns brightness, fans, battery limit, suspend
  flags, and all non-AC keyboard color.

## Risks / open validation items for implementation

- **OpenRGB ↔ asusd coexistence under real handoffs**: confirm that after ambient
  stops, `aura-repaint` (asusctl static) cleanly reasserts asusd control, and that
  starting ambient reliably grabs the device while asusd is loaded. Test live.
- **Matrix map correctness**: confirm `openrgb-python` exposes a usable
  `matrix_map`/`mat_width` for this device so column indices are right; fall back
  to LED-list order if the matrix is absent.
- **Frame rate / smoothness**: 15 Hz is a starting point; tune with smoothing.
  Per-key is one USB frame per update, far lighter than 4× `asusctl` calls.
- **uaccess for user services**: confirm the `systemd --user` service actually
  inherits the seat ACL (it should — same uid as the active session).

## Sync note

g815-only (NixOS). The macbook has no ASUS keyboard, so the mixin is imported
only on g815 and the enable flag stays off elsewhere — nothing to sync to darwin.
