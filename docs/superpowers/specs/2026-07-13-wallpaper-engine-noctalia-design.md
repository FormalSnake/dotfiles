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

A small helper `we-add <workshopid>` copies a scene's `preview.*` into the
wallpapers directory with the correct `we-<id>` name (quality-of-life; the same
result can be achieved by hand).

### 3. Selection hook

Append one call to Noctalia's existing `wallpaper_changed` hook (alongside
`flexokiScheme`). It parses `$NOCTALIA_WALLPAPER_PATH`:

- basename matches `we-<id>.*` → write `id=<id>` and
  `connector=$NOCTALIA_WALLPAPER_CONNECTOR` to `~/.cache/wallpaper-engine/state`.
- anything else → clear that state file.

Writing the state file is the only action; the reconciler (below) reacts to it.

### 4. Reconciler daemon

A `systemd.user.service` bound to `graphical-session.target` (same pattern as
`users/kyandesutter/mixins/autostart.nix`). It `inotifywait`-watches two inputs:

- `~/.cache/wallpaper-engine/state` — the current selection.
- `/run/power/state` — published by `power-reconcile`; one lowercase word,
  `ac` / `powerbank` / `battery`.

It enforces a single rule on every change:

> **the engine runs iff a scene is selected AND `/run/power/state` != `battery`.**

On each event it reconciles to that desired state: launch
`linux-wallpaperengine` on the selected connector, or kill the running instance.
Single-instance — it tracks the child PID and kills the previous engine before
relaunching on a selection change.

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
