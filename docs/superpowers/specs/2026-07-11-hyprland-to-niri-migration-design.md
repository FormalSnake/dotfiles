# Hyprland → niri migration (g815) — design

Date: 2026-07-11
Status: implemented 2026-07-11 (switch + first-login checklist pending on owner)
Supersedes the compositor-specific parts of
`2026-07-11-g815-power-gpu-redesign-design.md` (the power/GPU *model* from that
spec is unchanged; only its Hyprland glue is replaced).

## Goal

Replace Hyprland with niri (scrollable-tiling Wayland compositor) as the g815
session, as a **clean cut** — Hyprland is removed in the same change (NixOS
generations are the rollback path). Target the **latest niri release, 26.04**
(nixpkgs `pkgs.niri`), not niri-flake's older `niri-stable` (25.08).

Guiding rule (owner decision): **where niri natively implements something we
built a workaround for, adopt the native feature and delete the workaround.**

## Owner decisions

1. Clean cut — no Hyprland fallback session; rollback = NixOS generation.
2. Config via **sodiboo/niri-flake** `homeModules.niri` typed
   `programs.niri.settings` (build-time `niri validate`), binary pinned to
   nixpkgs `pkgs.niri` 26.04.
3. Replicate app→workspace→monitor pinning (named workspaces 1–9), embrace
   niri's scrollable-column layout for everything else.
4. Session snapshot/restore: **dropped** (autostart.nix relaunches nearly all
   apps; ad-hoc windows are accepted loss on relog).
5. `gpu-relog-prompt`: **battery branch kept** as a persistent
   [Relog now]/[Not now] notification — the dGPU idling while held costs
   significant battery, so a consent-only release path must exist. The
   monitor branch is deleted (niri hot-adds the dGPU at runtime).

## Key research facts (verified 2026-07-11)

- niri 26.04 (CalVer). Built-in xwayland-satellite integration since 25.08:
  niri exports `$DISPLAY` and spawns `xwayland-satellite` (≥ 0.7, must be on
  PATH) on demand. No manual X11 setup.
- **Multi-GPU: niri renders on the iGPU by default** (Smithay; no
  AQ_DRM_DEVICES equivalent needed). External outputs on the dGPU are driven
  by copying frames iGPU→dGPU.
- **DRM device hotplug confirmed in source** (`src/backend/tty.rs`,
  `UdevEvent::Added` → `device_added`): a dGPU whose modules load mid-session
  is initialized live and its HDMI output lights up — no relog. The reverse
  is NOT free: once initialized, niri holds an fd on the dGPU (creates a
  renderer on every non-ignored GPU, maintainer-confirmed) and there is no
  IPC to release it, so `modprobe -r nvidia*` stays blocked until logout.
  This is why the battery relog prompt survives.
- Native MRU **Alt-Tab switcher** since 25.11: top-level `recent-windows`
  section with its own `binds {}` (`next-window`/`previous-window`), live
  previews, hold-modifier semantics.
- Built-in: screenshot UI (`screenshot`, `screenshot-screen`,
  `screenshot-window` + `screenshot-path`), Overview (Mod+O / hot corner /
  4-finger swipe), dynamic screencast target, exit-confirmation dialog.
- IPC: `$NIRI_SOCKET`, `niri msg [--json] outputs|windows|version|...`,
  `niri msg action <141 actions>`, `event-stream` (19 event types — **no
  output-hotplug event**; udev remains the hotplug trigger, which our
  machinery already uses). **No runtime per-output on/off or mode-set via
  IPC** — runtime output changes go through config live-reload; 26.04 has
  `include optional=true` with `~` expansion for runtime-writable fragments,
  plus `niri msg action load-config-file` to force a reload.
- Session: `niri-session` script + `niri.service` (Type=notify,
  `BindsTo=graphical-session.target`, `Before=graphical-session.target`) —
  systemd-native, **no uwsm**. Ships `niri.desktop` for SDDM. Portals:
  `default=gnome;gtk` (`xdg-desktop-portal-gnome` required for screencast),
  `Secret=gnome-keyring`. Never set `GDK_BACKEND` globally (breaks
  screencast portal).
- Locking/idle: niri implements `ext-session-lock-v1` + `ext-idle-notify-v1`;
  Noctalia's locker and `lock-before-sleep` work unchanged.
- Noctalia v5 supports niri **first-class** (dedicated backend on
  `$NIRI_SOCKET` event-stream: workspaces, titles, per-monitor bars, overview
  state). Recommended niri-side extras: window-rule for
  `app-id="dev.noctalia.Noctalia"` (float), layer-rules for
  `^noctalia-wallpaper` / `^noctalia-backdrop` with
  `place-within-backdrop true`.
- nixpkgs has a `programs.niri` NixOS module (enable/package/useNautilus):
  session registration, GNOME+GTK portals, keyring. nixpkgs niri = 26.04.
  Upstream home-manager has **no** niri module — niri-flake's
  `homeModules.niri` is the only typed-settings surface.

## Architecture

### Flake

- Add input `niri` = `github:sodiboo/niri-flake` (`inputs.nixpkgs.follows`).
  Used **only** for `homeModules.niri`; packages come from nixpkgs.

### System side — `modules/nixos/mixins/niri.nix` (replaces `hyprland.nix`)

Everything compositor-agnostic carries over verbatim: SDDM (astronaut theme,
GPU-aware weston greeter), `lock-before-sleep`, polkit + gnome-keyring, gvfs/
tumbler/dconf, upower, fonts, backlight udev rules, i2c, and the generic
Wayland package set (brightnessctl, ddcutil, playerctl, wl-clipboard,
ffmpegthumbnailer). `grim`/`slurp` stay installed — our keybinds go native,
but Noctalia's own control-center screenshot UI may still shell out to them.

Changes:
- `programs.hyprland { enable, withUWSM, xwayland }` →
  `programs.niri.enable = true;` (package = nixpkgs niri 26.04).
- Add `xwayland-satellite` to packages (verify nixpkgs version ≥ 0.7).
- `xdg.portal.config.common.default = [ "gnome" "gtk" ]`; keep the explicit
  `org.freedesktop.impl.portal.Secret = gnome-keyring` pin. Drop
  xdg-desktop-portal-hyprland (came via programs.hyprland). Ensure
  `xdg-desktop-portal-gnome` is present (nixpkgs module wires it; verify).
- Option rename: `kyan.desktop.enable` description → "niri desktop".

### User side — `users/kyandesutter/mixins/niri.nix` (replaces `hyprland.nix`)

`programs.niri.settings` (niri-flake), containing:

- **Outputs:** `HDMI-A-1` 2560x1440@144 at 0,0 (primary/origin);
  `eDP-1` 2560x1600@240 at 2560,0 scale 1.25. VRR off (matches today).
- **Workspaces:** named workspaces `"1"`–`"9"`; `"4"` and `"8"` declared
  `open-on-output "eDP-1"`, the rest `"HDMI-A-1"`. Binds target by name.
- **Window rules** (same pinning as today): helium→1, Code/Zed→3,
  Slack/WhatsApp/Equibop/discord/Beeper/BlueBubbles→4, Claude→7, Spotify→8,
  Steam→9; PiP/popup floating rules; Noctalia settings window floats;
  noctalia wallpaper/backdrop layer-rules with `place-within-backdrop`.
- **Input:** es layout, `caps:escape`, clickfinger touchpad, natural-scroll
  and scroll factor as today.
- **Binds** (ported 1:1 unless noted):
  - Super+Space launcher, Super+ñ clipboard, Super+. emoji, Super+Shift+T
    theme toggle, Super+Shift+Escape lock-and-suspend — all `noctalia msg`.
  - Super+Return ghostty, Super+B helium, Super+Q close-window,
    Super+Shift+F fullscreen-window, Super+V toggle-window-floating.
  - Super+H/L focus-column-left/right; Super+J/K focus-window-down/up;
    Super+Shift+H/L move-column-left/right; Super+Shift+J/K
    move-window-down/up (vim-style, remapped to niri's column model).
  - Super+1..9 `focus-workspace "<name>"`; Super+Shift+1..9
    `move-column-to-workspace "<name>"`.
  - Super+Tab `focus-workspace-previous`.
  - New niri-native essentials: Super+O toggle-overview, Super+F
    maximize-column, Super+M maximize-window-to-edges, Super+Minus/Plus
    set-column-width ∓10%, Super+R switch-preset-column-width.
  - **Screenshots now native:** Print → `screenshot-screen`,
    Super+Shift+S → `screenshot` (interactive region UI). Noctalia
    screenshot IPC binds are dropped.
  - Volume/brightness/media XF86 keys → `noctalia msg` as today
    (`allow-when-locked=true` on volume/brightness).
  - Super+Shift+BackSpace → `gpu-relog-prompt confirm` (kept, see below).
- **recent-windows:** enabled with Alt+Tab / Alt+Shift+Tab (and the AltGr
  MOD5 variants if expressible). Replaces the Quickshell alttab entirely.
- **Environment block:** `QT_QPA_PLATFORMTHEME=qt6ct`, `QS_ICON_THEME`,
  `__GL_GSYNC_ALLOWED=1`, and the iGPU app pins previously computed by
  `env-hyprland`: `LIBVA_DRIVER_NAME=iHD`, `__EGL_VENDOR_LIBRARY_FILENAMES`,
  `VK_DRIVER_FILES` — now static nix-store paths (valid because the session
  is iGPU-primary always; no login-time GPU probing needed).
- **Cursor:** niri `cursor {}` block + `home.pointerCursor` (drop
  `hyprcursor.enable`; unify on one Bibata variant — today's config
  disagrees between Modern-Ice (env) and Modern-Classic (pointerCursor);
  pick Modern-Classic, the `home.pointerCursor` value).
- **Includes for runtime-mutable config** (the mechanism replacing
  `hyprctl eval`/`hyprctl keyword`): the generated config ends with two
  `include optional=true` fragments —
  1. `~/.cache/power-tune/edp-refresh.kdl` — owns the `output "eDP-1"` block
     (mode 240 vs 60Hz), rewritten by power-tune.
  2. `~/.cache/noctalia/niri-border.kdl` — owns the `layout {}` block
     (focus-ring/border colours from the wallpaper palette), rendered by
     Noctalia.
  To avoid duplicate-section conflicts, each fragment is the *sole* owner of
  its section — the main settings never declare `output "eDP-1"` or
  `layout`. Fragments are seeded at activation with defaults (240Hz;
  Catppuccin fallback colours) so first login before Noctalia renders is
  sane. After rewriting, callers run `niri msg action load-config-file`.
  ⚠️ Implementation-time check: confirm niri-flake settings can express
  `include` (else inject via `programs.niri.config`/`finalConfig`), and that
  include-fragment section merging validates.

Scripts (in the same mixin):

- **power-tune** (kept, re-targeted): aura-repaint on power-source change;
  refresh-follows-profile now rewrites `edp-refresh.kdl` + reloads config
  (instead of `hyprctl eval`); still kicks `dgpu-reconcile.service` once at
  start; same udev/PPD/inotify event loop. `runtimeInputs`: hyprland → niri.
  The service inherits `NIRI_SOCKET` via niri-session's environment import
  (same pattern as `HYPRLAND_INSTANCE_SIGNATURE` today).
- **gpu-relog-prompt** (simplified to battery-only): fires when
  `/run/power/state` = battery AND the nvidia DRM device exists/is held by
  the session AND no external monitor is connected on the dGPU. Persistent
  `notify-send -A relog -A dismiss` notification exactly as today; flock
  single-instance guard; `confirm` keybind fallback kept. On confirm:
  `niri msg action quit skip-confirmation=true` (replaces `uwsm stop`; no
  session snapshot first — restore is dropped). The monitor branch and the
  `session-gpu-mode` marker are deleted.
- **Deleted:** session-snapshot, session-restore, `env-hyprland`,
  `uwsm/env` (Qt vars move to the environment block).
- **Polkit agent:** hyprpolkitagent → `kdePackages.polkit-kde-agent-1`,
  started as a `graphical-session.target` user service (nothing left needs a
  compositor-start hook, so the old `hyprland.start` block has no successor).

### Noctalia — `users/kyandesutter/mixins/noctalia.nix`

- `hyprland-border` template → `niri-border` template: renders
  `~/.cache/noctalia/niri-border.kdl` (full `layout {}` with palette
  colours); `post_hook = niri msg action load-config-file`.
- `noctalia-templates/hypr-border.tmpl` → `niri-border.kdl.tmpl`.
- Delete the `alttab` template + `alttab.json.tmpl`. Trade-off: the native
  switcher's highlight colours are static config, so we lose the
  wallpaper-following colours the Quickshell switcher had — accepted;
  themable later via the same include-fragment mechanism if missed.
- `flexoki-scheme`: `hyprctl monitors` check → `niri msg --json outputs`
  (jq for a connected external output); `runtimeInputs` hyprland → niri;
  drop the `HYPRLAND_INSTANCE_SIGNATURE` comment/dependency (uses
  `NIRI_SOCKET`).
- Everything else (systemd unit, IPC keybind commands, templates, idle
  config) is compositor-agnostic and unchanged.

### Deletions (whole files)

- `users/kyandesutter/mixins/hyprland.nix` (replaced by `niri.nix`)
- `modules/nixos/mixins/hyprland.nix` (replaced by `niri.nix`)
- `users/kyandesutter/mixins/alttab.nix`
- `users/kyandesutter/noctalia-templates/hypr-border.tmpl`,
  `alttab.json.tmpl`
- `docs/hyprland-lua.md`

### Small edits elsewhere

- `users/kyandesutter/linux.nix`: import `./mixins/niri.nix`, drop
  hyprland/alttab imports.
- `modules/nixos/default.nix` + `profiles/desktop.nix`: import/describe the
  niri mixin.
- `modules/nixos/mixins/boot.nix`: earlyoom `--avoid` regex
  `Hyprland|.Hyprland-wrapp|hyprpolkitagent` → `niri|polkit-kde` (exact
  process names verified at implementation).
- `modules/nixos/mixins/nvidia-resume-recovery.nix`: liveness probe
  `hyprctl version` → `niri msg version` (discover `NIRI_SOCKET` from
  `$XDG_RUNTIME_DIR` the way lock-before-sleep discovers the Noctalia
  socket).
- `modules/nixos/mixins/nvidia.nix`, `helium.nix`, `qt.nix`,
  `desktop-apps.nix`, `locale.nix`, `phone-integration.nix`,
  `webapps.nix`, `autostart.nix`: comment-only updates (references to
  env-hyprland / hyprland.nix / uwsm).
- `CLAUDE.md` + `README.md` + memory bank: power-management section rewritten
  for the niri model (env-hyprland and relog-monitor-branch gone; battery
  relog prompt and include-fragment mechanism documented).

### Explicitly unchanged (load-bearing)

- `modules/nixos/mixins/power.nix` — zero changes (verified
  compositor-agnostic: power-source, power-reconcile, dgpu-power,
  dgpu-reconcile, `/run/power/state`, polkit rule, udev triggers).
- `modules/nixos/mixins/asus.nix`, `gaming.nix` (`game-mode`),
  `autostart.nix` services, SDDM/weston greeter, `lock-before-sleep`.
- All dgpu invariants hold: only dgpu-power touches nvidia modules; niri
  holding the device is treated exactly like Hyprland holding it (device
  stays powered; consent-only relog to release).

## Error handling

- Config errors fail at rebuild (`niri validate` via niri-flake), not login.
- Include fragments are `optional=true` — a missing/deleted fragment cannot
  break login; seeded defaults prevent a colour/refresh-less first session.
- If `niri msg` is unavailable (session dead), power-tune's refresh writes
  still land in the fragment and apply on next config load — no crash loop
  (scripts already `set -euo pipefail` with guarded IPC calls; keep that).
- Locker restart caveat (niri issues #2986/#2439): Noctalia's locker is
  systemd-managed; do not add auto-restart to any locker path.

## Testing / verification plan

1. `git add` everything; `nix-instantiate --parse` on new/changed .nix files.
2. `nix eval '.#nixosConfigurations.g815.config.system.stateVersion'` —
   module graph resolves.
3. Build g815 (`just b` / `nixos-rebuild build`) — proves niri validate
   passes and all packages exist. Switch needs owner sudo.
4. First niri login checklist: Noctalia bar/wallpaper up; workspaces pinned
   per output; autostart apps land on their workspaces; Alt+Tab native
   switcher; screenshots (Print / Super+Shift+S); volume/brightness keys;
   Steam (X11 via xwayland-satellite) launches; `niri msg --json outputs`
   sane.
5. Power model: on AC, kick `dgpu-reconcile` → nvidia loads → HDMI output
   appears live (hot-add). Unplug → battery → persistent relog notification
   appears (dGPU held). Relog → battery session without dGPU → modules
   unload, dGPU powers off. Refresh flip: PPD profile change flips eDP-1
   240↔60Hz. Wallpaper change recolours focus-ring live.
6. `darwin` host unaffected: `nix eval` the macbook stateVersion; nothing in
   this change touches shared/darwin modules.

## Risks / open items (resolve at implementation)

- niri-flake settings expressing `include` — may need `finalConfig` escape
  hatch. Include semantics for section ownership must be validated with
  `niri validate` during the build.
- nixpkgs `xwayland-satellite` version ≥ 0.7 (required by built-in
  integration).
- MOD5/AltGr recent-windows binds may not be expressible — acceptable loss
  (Alt+Tab is primary).
- `focus-workspace-previous` exact action name; `recent-windows` option
  names — verify against `niri validate` when building.
- Noctalia v5 is beta2 — its niri backend is first-class but young; any
  breakage is Noctalia-side (bar/workspaces display), not session-fatal.
