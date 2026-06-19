# Noctalia wallpaper-driven dynamic theming (replace global Catppuccin)

**Date:** 2026-06-19
**Status:** Approved design, pre-implementation
**Author:** kyandesutter (with Claude Code)
**Builds on:** `2026-06-19-noctalia-v5-migration-design.md` (the caelestia → noctalia V5 port)

## Goal

Make **Noctalia's wallpaper-derived palette the single source of truth** for the
desktop's colors, replacing the static global Catppuccin theme. When the active
wallpaper (or light/dark mode) changes, every app that *can* follow re-colors
automatically — including the **ASUS Aura keyboard**. Catppuccin is demoted to a
static fallback for the few things that genuinely can't be dynamic.

Not literal "base16": Noctalia generates a **Material Design 3 palette** (≈71
tokens — `primary`, `surface`, `on_surface`, the `terminal_*` roles, etc.) from
the wallpaper. Apps that want a base16 layout get M3 roles mapped into
`base00`–`base0F` by their template (the standard matugen-themes mapping). The
end result behaves exactly like a base16 scheme.

## Decisions (locked)

1. **Source:** `theme.source = "wallpaper"` — fully dynamic, Material You.
   `wallpaper_scheme = "m3-tonal-spot"` (balanced/legible; `vibrant` is the
   louder alternative — easy to change later).
2. **No rotation.** Wallpapers live in a **mutable** set under
   `~/Pictures/Wallpapers/{light,dark}`; Noctalia's picker shows the set but
   `wallpaper.automation.enabled = false`. Colors regenerate only on a manual
   wallpaper pick or a mode flip — never on a timer.
3. **Light + dark.** Manual toggle (Hyprland keybind → Noctalia mode-toggle IPC),
   with **per-mode wallpaper folders** (`directory_light` / `directory_dark`).
   Templates use the `.default` mode token so they track whichever mode is active
   and re-render on every flip.
4. **Catppuccin → static fallback only.** `autoEnable = false`; keep
   `enable = true; flavor = "mocha"` so it still feeds the apps that explicitly
   reference `config.catppuccin.*` (SDDM, Herdr, the Neovim pre-palette fallback,
   macOS jankyborders) and nothing else.
5. **Spicetify goes dynamic** by dropping `spicetify-nix` for a mutable
   **Flatpak Spotify** (via the existing `nix-flatpak` input) + `spicetify-cli`.
6. **Helium = GTK-follow.** No template; set Appearance → "Use GTK theme" once so
   it rides Noctalia's already-dynamic GTK colors.

## Architecture / trigger chain

(Verified against noctalia-shell V5 C++ source, commit `7bc707b`.)

```
manual wallpaper pick  ─┐
manual light/dark flip ─┤→ ThemeService.resolveAndSet()
                        │     → regenerate M3 palette (theme.source = wallpaper)
                        │     → TemplateApplyService.apply(palette, mode)
                        │         → render every theme.templates.user.* entry
                        │         → run each entry's pre_hook / post_hook
                        └─────────  (post_hook strings get color tokens
                                      interpolated before execution)
```

- Token format: `{{ colors.<role>.<mode>.<format> }}` — modes `default|dark|light`,
  formats `hex|hex_stripped|rgb|rgb_csv|rgba|hsl|hsla|red|…`; pipe filters
  (`lighten`, `darken`, `set_alpha`, `rotate_hue`, …) supported.
- The HM module's `programs.noctalia.settings` is freeform TOML written to
  `~/.config/noctalia/config.toml`; user templates are declared in-tree under
  `settings.theme.templates.user.<id>` (no separate `user-templates.toml`
  needed). The module restart-triggers the service on config changes.

## File-by-file changes

### 1. `users/kyandesutter/mixins/noctalia.nix`
Replace the static `theme` block and single-wallpaper block:

```nix
theme = {
  mode = "dark";                       # default; manual toggle flips it
  source = "wallpaper";
  wallpaper_scheme = "m3-tonal-spot";  # or "vibrant"
  templates = {
    enable_builtin_templates = true;
    builtin_ids = [ "gtk3" "gtk4" ];   # unchanged — GTK/Qt stay native
    user = {
      # entries below (§3)
    };
  };
};

wallpaper = {
  enabled = true;
  fill_mode = "crop";
  directory_dark  = "/home/kyandesutter/Pictures/Wallpapers/dark";
  directory_light = "/home/kyandesutter/Pictures/Wallpapers/light";
  automation.enabled = false;          # NO rotation
};
```

User-template entries (each points at an in-repo template file installed to
`~/.config/noctalia/templates/` via `home.file`/`xdg.configFile`):

```nix
theme.templates.user = {
  aura = {
    enabled = true;
    input_path  = "~/.config/noctalia/templates/aura.tmpl";
    output_path = "~/.cache/noctalia/aura-color";   # bare hex, for night-mode
    post_hook   = "asusctl aura effect static -c {{ colors.primary.default.hex_stripped }}";
  };
  ghostty = {
    enabled = true;
    input_path  = "~/.config/noctalia/templates/ghostty.tmpl";
    output_path = "~/.config/ghostty/themes/Matugen";
    post_hook   = "pkill -SIGUSR2 ghostty || true";
  };
  neovim = {
    enabled = true;
    input_path  = "~/.config/noctalia/templates/neovim.lua.tmpl";
    output_path = "~/.config/nvim/lua/noctalia_base16.lua";
    # no hook — dynamic-base16.nvim watches the file
  };
  equibop = {
    enabled = true;
    input_path  = "~/.config/noctalia/templates/equibop.css.tmpl";
    output_path = "~/.config/equibop/themes/noctalia.theme.css";
    # no hook — Equicord hot-reloads the themes folder
  };
  spicetify = {
    enabled = true;
    input_path  = "~/.config/noctalia/templates/spicetify.ini.tmpl";
    output_path = "~/.config/spicetify/Themes/Noctalia/color.ini";
    post_hook   = "spicetify watch -s 2>&1 | sed '/Reloaded/q' || true";
  };
};
```

Template files (committed to the repo, e.g. `users/kyandesutter/noctalia-templates/`):
- `aura.tmpl` — single line: `{{ colors.primary.default.hex_stripped }}` (the
  output file doubles as the night-mode color cache; the `post_hook` does the
  actual repaint).
- `ghostty.tmpl` — palette 0–15 + background/foreground/cursor/selection, all
  `.default` tokens (matugen-themes ghostty layout). Verified Ghostty loads
  `~/.config/ghostty/themes/<name>` via `theme = "Matugen"`; reload via SIGUSR2
  (Ghostty ≥ 1.2).
- `neovim.lua.tmpl` — `require('dynamic-base16').…` table OR a plain base16 lua
  module returning `base00..base0F` mapped from M3 roles (matugen-themes layout),
  using `.default` tokens.
- `equibop.css.tmpl` — refact0r midnight-discord base `@import` + `--bg/--text/
  --accent` overrides from `.default` tokens (same structure as the prior
  caelestia theme).
- `spicetify.ini.tmpl` — matugen-themes `color.ini` slot layout, `hex_stripped`,
  section name `[noctalia]`.

### 2. `users/kyandesutter/mixins/catppuccin.nix`
```nix
catppuccin = {
  enable = true;
  autoEnable = false;   # was true — stop blanket-theming every app
  flavor = "mocha";
};
```
Apps that still want it reference `config.catppuccin.*` explicitly (no change to
those references): SDDM, Herdr, Neovim fallback, jankyborders.

**Implementation note (added during build):** `autoEnable = false` also strips
Catppuccin from the terminal/CLI tools it was silently theming (`bat`, `btop`,
`fzf`, `lazygit`, `yazi`, `fish`, `tmux`) — and Noctalia has no template for
those. Since they have no dynamic path, they're re-enabled explicitly
(`catppuccin.<tool>.enable = true`) so they keep their Mocha theme. This is the
correct reading of "keep Catppuccin for apps that can't be dynamic."

### 3. `users/kyandesutter/mixins/ghostty.nix`
- Drop the catppuccin latte/mocha light-dark theme pair.
- Set `theme = "Matugen"` (loads the Noctalia-written
  `~/.config/ghostty/themes/Matugen`). Light/dark handled by Noctalia rewriting
  that file on mode flip + SIGUSR2 reload.

### 4. `users/kyandesutter/mixins/neovim.nix`
- Add plugin `GnRlLeclerc/dynamic-base16.nvim` with `watch = true`, reading
  `~/.config/nvim/lua/noctalia_base16.lua`.
- Keep `catppuccin/nvim` as the pre-palette fallback colorscheme (loads first;
  dynamic overrides once the file exists). Mirrors the matugen-themes fallback.

### 5. `users/kyandesutter/mixins/spicetify.nix` — IMPLEMENTED (option b)

**Status: implemented via a `--user` Flatpak Spotify + `spicetify-cli`.** Owner
chose option (b). spicetify is a host-side file patcher: it patches files inside
the Spotify app tree, so it needs a *writable* tree. Both `pkgs.spotify` (Nix
store) and a system Flatpak (`/var/lib/flatpak`, root) are read-only; a `--user`
Flatpak lives under `$HOME`, so its (still read-only OSTree) app tree can be
`chmod`-ed writable without sudo. No `flatpak run` wrapping / `flatpak override`
is needed (spicetify writes on the host side).

What was implemented:
- **flake.nix:** `spicetify-nix` input removed (change 8).
- **spicetify.nix (rewritten):** imports `nix-flatpak.homeManagerModules.nix-flatpak`;
  user install of `com.spotify.Client` + flathub remote; `home.packages =
  [ pkgs.spicetify-cli ]`; a guarded `home.activation.spicetifyChmod` that
  re-asserts writability of the app tree on each activation (no-ops until the app
  exists).
- **noctalia.nix:** `spicetify` user template → `Themes/Comfy/color.ini`, with
  `post_hook = "${pkgs.spicetify-cli}/bin/spicetify -c <abs config> apply
  --no-restart"` (absolute spicetify path because noctalia's systemd user-service
  PATH excludes the home profile).
- **noctalia-templates/spicetify.ini.tmpl:** M3→Comfy `color.ini` mapping,
  `hex_stripped`, `[Comfy]` section.

Manual first-run (owner, once, after rebuild — see Risks/owner steps): launch the
Flatpak Spotify once to populate its app tree + prefs, `chmod` the tree writable,
clone the **Comfy** theme into `~/.config/spicetify/Themes/`, `spicetify config`
the Flatpak `spotify_path`/`prefs_path` + `current_theme/color_scheme = Comfy`,
then `spicetify backup apply` with Spotify closed.

**Known maintenance tax:** every Spotify update re-deploys the OSTree tree,
wiping the chmod *and* the injection — re-run `chmod` (the activation handles this
on next `home-manager switch`) and `spicetify backup apply` (manual, Spotify
closed). Live recolor via `apply --no-restart` may need a `Ctrl+Shift+R` inside
Spotify to visibly refresh. This fragility is the accepted cost of runtime
recolor vs spicetify-nix's reliable-but-static build-time injection.

#### (original plan — superseded by the above)
- Remove `inputs.spicetify-nix` usage and the catppuccin theme.
- Install Spotify via **`nix-flatpak`** (mutable install spicetify can patch) +
  `pkgs.spicetify-cli`.
- One-time `spicetify backup apply` against the Flatpak Spotify (activation
  script or documented manual step; **verify exact Flatpak paths** —
  `~/.var/app/com.spotify.Client/...` — and that spicetify-cli can target it).
- Theme dir `~/.config/spicetify/Themes/Noctalia/` with a `user.css` consuming
  the `[noctalia]` color slots; `color.ini` is the dynamic output (§1).
- **Risk/fallback:** if Flatpak + spicetify-cli proves too fragile on NixOS,
  fall back to "Spotify stays static" (decided at implementation time).

### 6. `users/kyandesutter/mixins/hyprland.nix` (user)
- **Hyprland window borders** follow the accent too (added on request). Noctalia
  doesn't touch the compositor, so a `hyprland-border` user template's `post_hook`
  pushes colours live via `hyprctl keyword general:col.{active,inactive}_border`
  (instant, no reload). Runtime state, but re-applied on every session start /
  wallpaper / mode change. (Borders were previously unset → Hyprland defaults.)
- Add a light/dark **toggle keybind** → Noctalia mode-toggle IPC
  (**verify exact command**, e.g. `noctalia msg <dark-mode-toggle>`).
- Helium: documented one-time Appearance → "Use GTK theme" (no nix change;
  relies on the GTK builtin templates staying enabled). Optionally drop a note/
  comment.

### 7. `modules/nixos/mixins/asus.nix`
- `night-mode` "off": replace the hardcoded
  `asusctl aura effect static -c ${auraColour}` with a read of
  `~/.cache/noctalia/aura-color` (the live accent written by the `aura`
  template), falling back to `${auraColour}` (mauve) if the file is absent. So
  night-mode off restores *today's* wallpaper accent.
- `asus-aura` boot service: keep as the pre-session **seed** (paints before the
  Wayland session exists; Noctalia repaints to the wallpaper accent seconds after
  login). Optionally seed from `~/.cache/noctalia/aura-color` if present.
- Battery-dim udev rule: **unchanged** (operates on the brightness node, color
  preserved).

### 8. `flake.nix`
- Remove the `spicetify-nix` input (and its `follows`).
- `nix-flatpak` already present — reused for Spotify.

## What stays untouched

SDDM greeter (pre-login Mocha), Herdr (build-time theme), jankyborders (macOS),
the alttab switcher's `QS_ICON_THEME`, cursor (Bibata) / icon (Papirus) themes,
fonts, `power-profile-ac`, gaming/idle-inhibit wiring.

## Pre-work (owner, before first rebuild)

- Create `~/Pictures/Wallpapers/{light,dark}/` and drop wallpapers in. (Mutable,
  not tracked by the flake — by design.)

## Risks / verify after rebuild (owner runs the rebuild)

1. **Exact Noctalia keys:** `wallpaper.directory_{light,dark}`,
   `wallpaper.automation.enabled`, `theme.wallpaper_scheme`, and the
   `theme.templates.user.*` schema are taken from the V5 source; confirm they
   pass `noctalia config validate` at build time (the HM module runs it).
2. **Mode-toggle IPC command** name — verify the exact `noctalia msg …` verb.
3. **Spicetify on NixOS** (§5) — the biggest unknown: Flatpak Spotify path +
   whether `spicetify-cli` patches it cleanly and `watch -s` reloads. Fallback is
   static Spotify.
4. **Ghostty SIGUSR2** requires Ghostty ≥ 1.2; confirm the packaged version.
5. **Neovim** `dynamic-base16.nvim` availability in the lazyvim-nix plugin set;
   if unavailable, fall back to `RRethy/base16-nvim` + a `SIGUSR1` autocmd.
6. **Equibop** one-time enable: add the local theme to `enabledThemes` in
   `~/.config/equibop/settings/settings.json` (currently `[]`); midnight base is
   dark-oriented (light mode may look off).
7. **Helium** GTK-follow is an averaged color, not the exact accent;
   `prefers-color-scheme` may lag until restart (known Chromium bug).
8. **Aura in light mode:** `primary` can be pale → keyboard may look washed;
   consider a different role (e.g. a saturated `tertiary`) or a `saturate` filter
   if it reads poorly.

## Post-implementation notes (discovered at runtime)

- **Runtime state overrides declarative config.** Noctalia applies
  `~/.local/state/noctalia/settings.toml` (GUI-managed) *over* the HM-written
  `config.toml`. The old `source = "builtin"` was pinned there and a rebuild
  couldn't change it. Fix: `noctalia msg color-scheme-set wallpaper m3-tonal-spot`
  (or the GUI). Mode toggle is `noctalia msg theme-mode-toggle`.
- **Hyprland is 0.55 Lua parser** → `hyprctl keyword` is rejected ("Use eval").
  Runtime option-set is `hyprctl eval 'hl.config({...})'`. Our `hyprland-border`
  template replicates the builtin `hyprland` template's full property set
  (general borders + group + groupbar) via eval, because the builtin appends
  `require("noctalia")` to the read-only HM `hyprland.lua` and doesn't re-apply
  live.
- **Qt enabled** (`builtin_ids += "qt"`): qt6ct/qt5ct installed,
  `QT_QPA_PLATFORMTHEME=qt6ct`, qt{5,6}ct.conf select the Noctalia colour scheme
  (Fusion style). Restyles all Qt apps at launch.
- **btop** moved from static Catppuccin → dynamic (`builtin_ids += "btop"`,
  `programs.btop.settings.color_theme = "noctalia"`).
- **Live-recolour matrix.** Live (reload signal): Noctalia shell, ghostty
  (SIGUSR2), neovim (file-watch), Equibop (CSS watch), Aura keyboard, Hyprland
  borders (eval). Launch-time only (toolkit/app has no palette hot-reload): GTK
  apps, Qt apps, Spotify (Ctrl+Shift+R or relaunch). This is inherent, not a
  config bug. Acceptable because wallpaper changes are manual/infrequent.
- **yazi enabled** (community template): writes a `noctalia` flavor; its apply.sh
  auto-points `~/.config/yazi/theme.toml` at it. Removed from the Catppuccin
  static list. Works on next yazi launch, no manual steps.
- **steam enabled** (community template) — themes via the **Millennium** patcher,
  which is now nix-managed (`programs.steam.package = millennium-steam`, built
  from Millennium's `steam.nix` so the dGPU-offload `extraEnv` is preserved).
  One-time runtime/GUI step remains: in Millennium install the Material-Theme
  skin (ID `ipYjqODds05KMcvh7QJn`), pick the "Matugen" colour, restart Steam.
- **Still available, not enabled:** community templates for `telegram`, `zathura`,
  `obsidian`, etc. (not used on this host or deferred).

## Out of scope

- Theming SDDM/Herdr dynamically (can't — pre-login / build-time).
- Full Material-You browser chrome on Helium (doesn't exist on Linux).
- Any rebuild/activation — staged via `git add` only; the owner rebuilds.
