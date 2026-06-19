# Migrate caelestia → noctalia V5 (faithful 1:1 port)

**Date:** 2026-06-19
**Status:** Approved design, pre-implementation
**Author:** kyandesutter (with Claude Code)

## Goal

Replace the caelestia Quickshell desktop shell with **noctalia V5 (alpha)** on the
g815 NixOS host, reproducing the current look/feel and keybinds as faithfully as
noctalia allows. Motivation: better customizability and performance.

Reference: https://docs.noctalia.dev/v5/getting-started/nixos/

## Decisions (locked)

1. **Port fidelity:** Faithful 1:1 — Catppuccin Mocha (dark), `storm.jpg`
   wallpaper, Geist / GeistMono fonts, same keybinds, opaque panels, on-demand
   sleep.
2. **Build approach:** Build from source, `inputs.nixpkgs.follows = "nixpkgs"`.
   No cachix substituter.
3. **Cutover:** Full clean replacement. Delete `caelestia.nix`, remove the flake
   input and the launcher-global / wallpaper / scheme activation hacks. Fallback
   is via git history (`git revert`).
4. **Dark mode / app theming:** Route through **noctalia's GTK/Qt app-theming
   templates** (palette injection), trimming the declarative `gtk` module's
   color ownership to avoid both writing the same files. (See Risks for the
   portal `prefer-dark` caveat.)

## Key facts about noctalia V5

- **Native C++ / OpenGL ES**, binary `noctalia` (V4 was Quickshell `qs` /
  `noctalia-qs`; V5 is a ground-up rewrite — this is the performance win).
  Consequence: noctalia does **not** read `QS_ICON_THEME`. The alttab switcher
  (`alttab.nix`) is still Quickshell/Qt6 and **does**, so that env var stays.
- HM module: `inputs.noctalia.homeModules.default`, configured via
  `programs.noctalia = { enable; systemd.enable; settings = {…}; }`.
  (Note the attr name `homeModules`, vs caelestia's `homeManagerModules`.)
- **Wallpaper and theme are declarative** in the module
  (`settings.theme`, `settings.wallpaper`) — both caelestia activation-script
  hacks (`caelestiaWallpaper`, `caelestiaScheme`) are removed.
- Config is TOML (`~/.config/noctalia/settings.toml`, `templates.toml`).
  `settings.toml` is GUI/runtime-managed; the HM module writes the declarative
  baseline. App-theming templates may live in `templates.toml`.

## Command / keybind mapping

| Caelestia | Noctalia V5 |
|---|---|
| `caelestia:launcher` (Hyprland global) | `noctalia msg panel-toggle launcher` (exec) |
| `caelestia screenshot` | `noctalia msg screenshot-fullscreen` |
| `caelestia screenshot -r -f` | `noctalia msg screenshot-region` |
| session "sleep" (hibernate-slot hack) | `noctalia msg session lock-and-suspend`; no hack needed |
| `caelestia scheme set -n catppuccin -f mocha -m dark` | `settings.theme = { mode = "dark"; source = "builtin"; builtin = "Catppuccin"; }` |
| `caelestia wallpaper -f <path>` | `settings.wallpaper = { enabled = true; default.path = <storm.jpg>; }` |

## File-by-file changes

### 1. `flake.nix`
Replace the `caelestia-shell` input with:
```nix
noctalia = {
  url = "github:noctalia-dev/noctalia";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

### 2. `users/kyandesutter/mixins/noctalia.nix` (new; `caelestia.nix` deleted)
- `imports = [ inputs.noctalia.homeModules.default ];`
- `programs.noctalia = { enable = true; systemd.enable = true; settings = {…}; };`
- Settings mirror caelestia within noctalia's schema:
  - `theme = { mode = "dark"; source = "builtin"; builtin = "Catppuccin"; }`
  - `wallpaper = { enabled = true; default.path = <in-repo storm.jpg store path>; }`
  - UI font → Geist; monospace → GeistMono Nerd Font (noctalia `font_family` /
    equivalent key — **verify exact key names**).
  - Battery widget enabled; opaque/`solid` panel transparency (caelestia's
    `appearance.transparency.enabled = false`).
  - GTK/Qt app theming templates (see change 7).
- Remove both `home.activation.caelestia*` blocks.
- Any caelestia setting with no clean noctalia equivalent is left at noctalia's
  default and marked with a `# TODO: verify` comment.

### 3. `users/kyandesutter/linux.nix`
Swap import `./mixins/caelestia.nix` → `./mixins/noctalia.nix`.

### 4. `users/kyandesutter/mixins/hyprland.nix`
- Launcher (~296): `hl.dsp.global("caelestia:launcher")` →
  `hl.dsp.exec_cmd("noctalia msg panel-toggle launcher")`.
- Screenshots (349–350): → `noctalia msg screenshot-fullscreen` /
  `noctalia msg screenshot-region`.
- Sleep (314): `systemctl suspend` → `noctalia msg session lock-and-suspend`
  (preserves lock-before-sleep); update comment, drop the hibernate-hack
  reference.
- `QS_ICON_THEME` env (509): **keep** — still required by alttab (Quickshell).
  Rewrite the comment to drop caelestia and reference alttab + noctalia's dark
  theme.
- Comment-only updates: polkit-agent note (~191), idle-inhibit notes (307–313).

### 5. `modules/nixos/mixins/hyprland.nix`
- **Keep all functionality:** SDDM static wallpaper + Mocha baking (the greeter
  runs pre-login and can't read shell state — still true for noctalia), UPower,
  fonts, ddcutil.
- Update the header comment + the "if these change, update here too" note to
  track `noctalia.nix` instead of `caelestia.nix`.

### 6. `modules/nixos/mixins/{bluetooth,gaming,asus}.nix`
- Comment-only updates: bluetooth daemon now backs `noctalia msg
  bluetooth-toggle`; idle-inhibit still works via the Wayland `ext-idle-notify`
  protocol, which noctalia's idle service honors; PPD/UPower back noctalia's
  power/battery readouts.

### 7. Dark mode / app theming (noctalia-owned)
- In `noctalia.nix` settings, enable the builtin template catalog and opt into
  the official GTK + Qt template(s):
  ```toml
  [theme.templates]
  enable_builtin_templates = true
  builtin_ids = [ <gtk-id>, <qt-id> ]   # discover via: noctalia theme --list-templates
  ```
  (Exact HM key path and whether this maps into `settings` or a separate
  `templates.toml` is **verified during implementation** against the HM module
  source.)
- Adjust the declarative `gtk` block in `users/kyandesutter/mixins/hyprland.nix`
  so it no longer fights noctalia over palette/color files: noctalia owns the
  injected GTK/Qt colors; the gtk module retains only non-color concerns it must
  keep (icon theme via Papirus, cursor, fonts, and the
  `gtk-application-prefer-dark-theme` flag for X11/XWayland apps). Determine the
  exact files noctalia writes and ensure no double-ownership.

## Risks / verify after rebuild (owner runs the rebuild)

1. **noctalia `settings` key names** for font / battery / panel opacity are
   free-form — wrong keys are silently ignored, so faithful styling may need one
   tweak pass after first boot.
2. **Portal `prefer-dark` signal:** caelestia asserted the
   `org.freedesktop.appearance color-scheme = prefer-dark` portal signal that
   native-Wayland libadwaita/GTK4 apps read. noctalia's app-theming is template
   injection, **not** a portal backend — this is undocumented for V5. If native
   Wayland apps go light after cutover, add an explicit dconf
   `org/gnome/desktop/interface color-scheme = "prefer-dark"` as a fallback.
3. **GTK/Qt template double-ownership:** confirm noctalia and the HM gtk module
   don't both write the same files (change 7).
4. **Screenshot behavior:** save location / clipboard / notification may differ
   slightly from caelestia's integrated tool.
5. **Autostart model:** noctalia V5 docs recommend compositor autostart
   (`exec`/`--daemon`); we use `systemd.enable = true` (parity with caelestia,
   bound to the Wayland/graphical-session target). Verify the service starts and
   reaches the session target under uwsm.

## Out of scope

- Restyling beyond Mocha parity (deferred — customize from noctalia's baseline
  after the port lands).
- Migrating the alttab switcher off Quickshell (unrelated; it stays).
- Any rebuild/activation — staged via `git add` only; the owner rebuilds.
