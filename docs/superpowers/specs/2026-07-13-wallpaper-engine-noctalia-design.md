# Wallpaper Engine on g815, Noctalia-native

**Date:** 2026-07-13
**Host:** g815 (NixOS). macbook is `aarch64-darwin` and cannot run
`linux-wallpaperengine`, so this feature is intentionally **g815-only** and
carries no cross-host sync obligation. The mixin is imported solely from
`users/kyandesutter/linux.nix`.

## Goal

Play animated Wallpaper Engine scenes on the g815 niri/Noctalia desktop
**without disturbing the wallpaper-derived matugen theming pipeline**, and
**without fighting the load-bearing power management** — animation pauses on
battery and resumes on AC/power-bank automatically.

## Decision: hook-driven, Noctalia stays the source of truth

Noctalia already owns the wallpaper and the palette: it fires the
`wallpaper_changed` hook with `$NOCTALIA_WALLPAPER_PATH` /
`$NOCTALIA_WALLPAPER_CONNECTOR`, and the config already piggybacks on that hook
with `flexokiScheme` (per-wallpaper colour-source flip, in
`users/kyandesutter/mixins/noctalia.nix`). We build on that same seam rather
than adopting the two community projects:

- `HomieDerPrakti/wallpaperengine-noctalia` (QML) — a bare example skeleton
  (v0.0.1, "A simple example plugin", a `count` setting). Not functional.
- `SaigyoujiLuna/linux-wallpaperengine-noctalia` (Python/GTK4) — functional, but
  runs its **own** wallpaper GUI alongside Noctalia's picker (two sources of
  truth) and colours the theme by **screenshotting the live surface** — the
  "sample a live frame" approach we explicitly rejected. Also `uv`/GTK4
  packaging in nix is fiddly.

The hook approach keeps Noctalia's picker as the single UI, keeps matugen as the
theme source (colours come from a **still preview image**, never the live
surface), and adds no immature third-party dependency. It matches the repo's
"Noctalia > compositor-native > custom workaround" preference.

`linux-wallpaperengine` is already in nixpkgs (`0-unstable-2026-05-12`) and
supports Wayland via `wlr-layer-shell` + `xdg-output`, both of which niri
implements. Wallpaper Engine is owned on Steam, so the shared assets are present
on g815 under the standard Steam workshop path.

## Design

New mixin **`users/kyandesutter/mixins/wallpaper-engine.nix`** (one concern),
imported from `users/kyandesutter/linux.nix`. Five parts:

### 1. Package

`home.packages += pkgs.linux-wallpaperengine`.

### 2. Selection convention

A Wallpaper Engine scene appears in Noctalia's picker as a **still image** named
`we-<workshopid>.<ext>` in `~/Pictures/Wallpapers/{light,dark}` — normally the
scene's own `preview.*` from
`~/.steam/steam/steamapps/workshop/content/431960/<id>/`. Noctalia renders and
matugen-samples that still, so the **theming pipeline is unchanged**. Any
wallpaper without the `we-` prefix behaves exactly as today.

Three helper commands (scripts on `PATH`, usable from fish or any shell):

- `we-list [search]` — list installed scenes (`id  type  title`), optionally
  filtered by title substring. This is how you find an id.
- `we-set <id> [fps]` — apply a scene to **every connected output** in one
  command: it ensures the still is in the picker set, optionally writes the
  engine fps, then points each niri output at it via `noctalia msg
  wallpaper-set`.
- `we-add <id> [light|dark]` — copy a scene's preview into the picker set
  without applying it (for populating the light set, etc.).

### 3. Selection hook

Append one call to Noctalia's existing `wallpaper_changed` hook (alongside
`flexokiScheme`). It parses `$NOCTALIA_WALLPAPER_PATH` **per output**:

- basename matches `we-<id>.*` → write `<id>` to
  `~/.cache/wallpaper-engine/outputs/$NOCTALIA_WALLPAPER_CONNECTOR`.
- anything else → remove that output's file.

Per-output state (not a single global file) is what makes multi-monitor work:
each connector can independently hold an animated scene or a plain wallpaper.

### 4. Reconciler daemon

A `systemd.user.service` bound to `graphical-session.target` (same pattern as
`users/kyandesutter/mixins/autostart.nix`). It `inotifywait -r`-watches two
inputs:

- `~/.cache/wallpaper-engine/` — the per-output selection dir plus the optional
  `fps` file (default 60; 30 looks choppy on the 240 Hz panel, and we only ever
  run on AC so the extra cost is acceptable).
- `/run/power/state` — published by `power-reconcile`; one lowercase word,
  `ac` / `powerbank` / `battery`.

It enforces a single rule on every change:

> **one engine spans every output with a scene selected, iff not on battery.**

On each event it rebuilds the launch command from all
`outputs/<connector>` files (`--screen-root C --bg ID` per output) plus the fps,
compares a stable signature against the running one, and restarts the single
engine only when the desired set actually changed (so hover-preview bursts and
no-op events don't thrash the GL engine).

This is a **new, independent reader** of `/run/power/state` — purely additive,
touching none of the load-bearing power services in
`modules/nixos/mixins/power.nix` or `users/kyandesutter/mixins/niri.nix`. It is
exactly the "subscribe to it" seam that `power.nix` documents. It watches the
`/run/power/` **directory** (not the file inode) so it survives
`power-reconcile`'s write-and-rename.

### 5. Power resume (free consequence)

Plugging in → `power-reconcile` rewrites `/run/power/state` → the daemon's
inotify fires → animation resumes on the currently-selected scene. Unplugging →
engine killed; the still (with its already-derived palette) remains. No changes
to any existing power code.

## Risks / to validate at implementation

- **Z-order (the one real risk).** Both Noctalia's wallpaper and
  `linux-wallpaperengine` draw on the `wlr-layer-shell` background layer. The
  engine, mapped later, *should* stack on top under niri, but two same-layer
  surfaces need a live check. If the engine loses the z-fight, the fallback is
  to have Noctalia drop its wallpaper on that output **after** it has generated
  the palette (the still is only needed as a colour source + picker thumbnail,
  not as a persistent visible surface). Only pursue the fallback if the test
  fails.
- **Exact CLI flags.** Confirm the single-connector background invocation
  (`--screen-root <name> --bg <id>` vs `--screen-span` for multi-monitor) and
  any `--fps`/asset-dir flags against the installed build before wiring the
  launch command.

## Verification

1. `nix build` the package (and `nix flake check` / eval as applicable).
2. Rebuild g815 (`nixos-rebuild` / `just` recipe). Sudo caveat: hand the
   privileged step to the owner if it blocks on a password.
3. Manual:
   - Pick a `we-<id>` wallpaper → engine animates; palette matches the still.
   - Pick an ordinary wallpaper → engine stops; behaves as before.
   - Unplug charger → animation stops, still + palette unchanged.
   - Replug → animation resumes automatically.

## Scope guardrails

- Do **not** modify `power-reconcile`, `dgpu-reconcile`, or the niri power-tune
  logic — this feature only *reads* `/run/power/state`.
- No macbook / darwin change; no cross-host sync obligation.
