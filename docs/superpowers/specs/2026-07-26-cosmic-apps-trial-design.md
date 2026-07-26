# COSMIC apps trial (side-by-side, themed, square)

**Date:** 2026-07-26
**Status:** Approved
**Hosts:** g815 + e1504g (shared Linux home config; macbook untouched)

## Goal

Try the COSMIC app ecosystem as a possible replacement for the GNOME app
suite, without disrupting the daily setup: the session stays niri + DMS, the
GNOME apps stay installed and remain the MIME defaults. COSMIC apps are
launched deliberately (DMS launcher) for evaluation. Revert = delete one
import line.

The apps must follow the wallpaper-derived matugen theming like every other
themed surface, and must render **square** — the owner wants a square system
and COSMIC's stock theme forcibly rounds windows and widgets.

## Decisions

- **Side-by-side trial**, not a swap: no GNOME app removals, no
  `xdg.mimeApps` changes. GNOME keeps covering the gaps COSMIC has no answer
  for (image viewer, calendar, clocks, maps, camera, spacebar preview).
- **App set:** `cosmic-files`, `cosmic-edit`, `cosmic-player`,
  `cosmic-reader` (PDF, pre-release), plus community apps `tasks` and
  `forecast`. Excluded: `cosmic-term` (Ghostty is themed and staying),
  `cosmic-store` (Flatpak-oriented, useless on NixOS), `cosmic-screenshot`
  (needs COSMIC's own portal), `cosmic-ext-tweaks` (only useful in a real
  COSMIC session).
- **`cosmic-settings` is included as tooling, not as an app**: its
  `cosmic-settings appearance import <file.ron>` subcommand (present in the
  packaged 1.2.0 / settings 1.0.12, verified) is the headless theme applier;
  the GUI Appearance page is the escape hatch for manual tweaks.
- **No Flexoki fallback seed** for the pre-first-matugen state: COSMIC's
  stock dark theme is an acceptable cold-start default and DMS re-runs
  matugen every login. Add later only if it grates.
- **Blur:** libcosmic/iced has no backdrop blur; not configurable, out of
  scope. Fine for a square system.

## Design

### 1. New mixin `users/kyandesutter/mixins/cosmic-apps.nix`

Imported from `users/kyandesutter/linux.nix` (COSMIC apps are Linux-only).
Contents: `home.packages` with the six trial apps + `cosmic-settings`.
One concern per file, per repo convention.

### 2. Matugen template `users/kyandesutter/matugen-templates/cosmic.theme.ron`

A COSMIC `ThemeBuilder` RON file with matugen color placeholders, based on
the InioX/matugen-themes community `cosmic_theme.ron` template. Two changes
from the community version:

- **Colors are emitted in COSMIC's 0–1 float form** (matugen color format
  filters, or a normalization step in the post-hook) — the community
  template emits 0–255 and papers over it with a Python script; we do not
  ship Python for this.
- **`corner_radii` pinned to 0 across all radius steps** (`radius_0` …
  `radius_xl`), producing square windows and widgets. This is the same
  mechanism cosmic-ext-tweaks uses for its square style.

### 3. Registration + apply hook in `mixins/dms.nix`

Registered in the generated matugen `config.toml` alongside the existing
user templates (aura, ghostty, niri-border, …), so DMS re-renders it on
every wallpaper pick and light/dark flip. Render target lives with the
other runtime artifacts (`~/.cache/dank/`). The `post_hook`:

1. Runs `cosmic-settings appearance import <rendered file>` — it derives
   the full theme from the builder and writes the
   `com.system76.CosmicTheme.{Dark,Light}` config files that running
   libcosmic apps watch, so re-theming is live.
2. Syncs COSMIC's mode flag (`com.system76.CosmicTheme.Mode` `is_dark`) to
   the mode DMS just rendered, so apps pick the matching variant.

### Open items for the implementation plan

- Confirm `appearance import` works headless under niri (no COSMIC session/
  daemon) by importing once and checking `~/.config/cosmic/` output.
- Confirm which mode (dark/light) an import lands in and whether the mode
  flag must be set before or after the import.
- Exact matugen keyword/filter syntax for 0–1 floats.

## Verification

1. `git add` new files, rebuild g815, launch `cosmic-files` under niri.
2. Pick a wallpaper in DMS → cosmic-files re-colors live, square corners.
3. Flip light/dark in DMS → COSMIC apps follow.
4. GNOME defaults unchanged: `xdg-open` on a folder still opens Nautilus.
5. Push; one-shot e1504g rebuild to keep hosts in sync.

## Out of scope

- Full COSMIC session at SDDM.
- MIME default changes; GNOME app removals.
- Flexoki fallback seeding for COSMIC.
- Blur (unsupported by libcosmic).
