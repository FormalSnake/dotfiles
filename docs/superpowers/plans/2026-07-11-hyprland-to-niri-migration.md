# Hyprland → niri Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Hyprland with niri 26.04 as the g815 session (clean cut), per the approved spec `docs/superpowers/specs/2026-07-11-hyprland-to-niri-migration-design.md`.

**Architecture:** System side swaps `programs.hyprland` for nixpkgs' `programs.niri` (session, portals, keyring). User side replaces the hand-written `hyprland.lua` with niri-flake's typed `programs.niri.settings` (build-time `niri validate`), plus two raw-KDL appendices (`include optional=true` fragments + `recent-windows`) that the schema can't express. Runtime-mutable config (eDP refresh flip, wallpaper border colours) moves from `hyprctl eval` to rewritable KDL fragments + `niri msg action load-config-file`. `power.nix` is untouched.

**Tech Stack:** NixOS + home-manager (flake-parts), sodiboo/niri-flake `homeModules.niri`, nixpkgs `pkgs.niri` 26.04, `pkgs.xwayland-satellite` 0.8.1, Noctalia v5.

## Global Constraints

- niri binary = **nixpkgs `pkgs.niri` (26.04)** everywhere (never niri-flake's `niri-stable`/`niri-unstable`; no overlay).
- `modules/nixos/mixins/power.nix` must not change — verify with `git diff --stat` before every commit.
- `git add` every new/changed file before any nix eval/build (flakes ignore unstaged files).
- After each task: `nix eval '.#nixosConfigurations.g815.config.system.stateVersion'` must succeed (avoid evaluating `home-manager.users.*` paths — IFD).
- Commits: short imperative lowercase with conventional prefix, no co-author line, no description body.
- Verified facts (do not re-research): niri renders iGPU-default; hot-adds DRM devices at runtime; holds an fd on every non-ignored GPU (battery relog prompt must stay); no IPC output on/off (fragments + `load-config-file` instead); `recent-windows` + `include optional=true` are niri ≥25.11/26.04 runtime features absent from the niri-flake schema; `binds.<key>.action.<name> = args` attrset form is the documented niri-flake API; `cursor.theme`/`cursor.size` option names; `environment` attrset with null=unset; window-rules/layer-rules are LISTS; workspaces attrset with `open-on-output`.
- Bind actions confirmed to exist: `focus-workspace-previous`, `maximize-window-to-edges`, `switch-preset-column-width`, `toggle-overview`, `quit skip-confirmation=true`, `set-column-width "-10%"`, `screenshot`, `screenshot-screen`, `close-window`, `fullscreen-window`, `toggle-window-floating`, `focus-column-left/right`, `focus-window-up/down`, `move-column-left/right`, `move-window-up/down`, `move-column-to-workspace`, `focus-workspace`.

---

### Task 1: Add the niri-flake input

**Files:**
- Modify: `flake.nix` (after the `noctalia` input block, ~line 121)

**Interfaces:**
- Produces: `inputs.niri.homeModules.niri` (consumed by Task 3).

- [ ] **Step 1: Add the input** after the `noctalia` input block:

```nix
    # niri scrollable-tiling compositor. The flake is used ONLY for its typed
    # home-manager settings module (programs.niri.settings → KDL, validated
    # with `niri validate` at build time); the niri binary itself comes from
    # nixpkgs (26.04) — niri-flake's own niri-stable lags behind.
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

- [ ] **Step 2: Lock and verify**

Run: `git add flake.nix && nix flake lock && git add flake.lock`
Then: `nix eval '.#nixosConfigurations.g815.config.system.stateVersion'`
Expected: prints the stateVersion, no errors.

- [ ] **Step 3: Commit** — `git commit -m "feat(niri): add sodiboo/niri-flake input"`

---

### Task 2: System-side niri module (replaces modules/nixos/mixins/hyprland.nix)

**Files:**
- Create: `modules/nixos/mixins/niri.nix`
- Delete: `modules/nixos/mixins/hyprland.nix`
- Modify: `modules/nixos/default.nix:24` (import), `modules/nixos/profiles/desktop.nix:6,9-10` (description), `modules/nixos/mixins/boot.nix:206` (earlyoom), `modules/nixos/mixins/nvidia-resume-recovery.nix` (probe)

**Interfaces:**
- Produces: `config.programs.niri.package` (nixpkgs module; consumed by nvidia-resume-recovery), `kyan.desktop.enable` unchanged.

- [ ] **Step 1: Create `modules/nixos/mixins/niri.nix`** — copy `modules/nixos/mixins/hyprland.nix` verbatim, then apply exactly these changes (everything else — `lockBeforeSleep`, `sddmAstronaut`, `sddmWestonIni`, `sddmGreeterCompositor`, SDDM block, polkit/keyring, lock-before-sleep unit, gvfs/tumbler/dconf, GIO_EXTRA_MODULES, upower, fonts, udev backlight rule, i2c, systemPackages — carries over unchanged):

Replace the option description (line 88):
```nix
  options.kyan.desktop.enable = lib.mkEnableOption "niri desktop (system side)";
```

Replace the `programs.hyprland` block (lines 91-95) with:
```nix
    # niri session (nixpkgs module): installs the package, registers the
    # Wayland session for SDDM, wires portals (gnome for screencast + gtk
    # fallback) and gnome-keyring. niri is systemd-native (niri-session →
    # niri.service, BindsTo graphical-session.target) — no uwsm.
    programs.niri.enable = true;

    # X11 apps (Steam & co): niri ≥25.08 spawns xwayland-satellite on demand
    # and exports DISPLAY by itself — the binary just has to be on PATH.
    environment.systemPackages = [ pkgs.xwayland-satellite ];
```
(Merge that `environment.systemPackages` line into the existing list at the bottom of the file instead of declaring it twice — add `xwayland-satellite` to the existing `environment.systemPackages` list, next to `grim`/`slurp`. Keep `grim`/`slurp`: our keybinds go niri-native but Noctalia's control-center screenshot tooling may still shell out to them.)

Replace the `xdg.portal` block (lines 97-111) with:
```nix
    # xdg portals: niri routes screencast through xdg-desktop-portal-gnome and
    # the rest through gtk (programs.niri wires the packages; this pins the
    # routing). gnome-keyring's Secret portal is gated `UseIn=gnome`, and
    # $XDG_CURRENT_DESKTOP=niri bypasses it — keep the explicit pin so
    # sandboxed Flatpaks can reach the keyring.
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common = {
        default = [ "gnome" "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
    };
```

Update the SDDM comment (lines 113-115): the session file is now `niri.desktop` (Exec=niri-session), installed by `programs.niri` into the same wayland-sessions dir. No code change.

- [ ] **Step 2: Point the module tree at it** — in `modules/nixos/default.nix` replace `./mixins/hyprland.nix` with `./mixins/niri.nix`; in `modules/nixos/profiles/desktop.nix` update the enable-option description to "niri desktop profile" and the comment to reference `../mixins/niri.nix`. Delete `modules/nixos/mixins/hyprland.nix` (`git rm`).

- [ ] **Step 3: earlyoom** — in `modules/nixos/mixins/boot.nix:206` replace the avoid regex:

```nix
      "^(niri|noctalia|polkit-kde-aut|sshd|systemd)$"
```
(`Hyprland`/`.Hyprland-wrapp` → `niri`; `hyprpolkitagent` → `polkit-kde-aut` — comm names truncate at 15 chars, the agent binary is `polkit-kde-authentication-agent-1`; `quickshell` dropped — the alttab Quickshell instance is deleted in Task 3.)

- [ ] **Step 4: nvidia-resume-recovery** — in `modules/nixos/mixins/nvidia-resume-recovery.nix`:
  - `runtimeInputs`: replace `config.programs.hyprland.package` with `config.programs.niri.package`.
  - Replace the instance check + `alive()` (lines 37-44) with:

```nix
      # No live niri instance (resumed to the greeter, session gone) → nothing
      # to recover, and don't restart-loop the DM. niri msg needs NIRI_SOCKET
      # ($XDG_RUNTIME_DIR/niri.<wayland-display>.sock) — discover it the same
      # way lock-before-sleep discovers noctalia's socket.
      sock=""
      for s in "$runtime"/niri.*.sock; do
        [ -e "$s" ] && sock="$s" && break
      done
      [ -n "$sock" ] || exit 0

      alive() {
        runuser -u "$user" -- env XDG_RUNTIME_DIR="$runtime" NIRI_SOCKET="$sock" \
          timeout 5 niri msg version >/dev/null 2>&1
      }
```
  - Update the two comments and the unit description that say "Hyprland" to say "niri" (the driver bug and probe logic are unchanged).

- [ ] **Step 5: Verify + commit**

Run: `git add -A && nix eval '.#nixosConfigurations.g815.config.system.stateVersion'`
Expected: prints stateVersion. Then `git diff --stat HEAD -- modules/nixos/mixins/power.nix` → empty.
Commit: `git commit -m "feat(niri): system-side niri session replacing hyprland"`
(Eval still passes because the user-side hyprland mixin never references `config.programs.hyprland`.)

---

### Task 3: User-side niri mixin (replaces users/kyandesutter/mixins/hyprland.nix + alttab.nix)

**Files:**
- Create: `users/kyandesutter/mixins/niri.nix`
- Delete: `users/kyandesutter/mixins/hyprland.nix`, `users/kyandesutter/mixins/alttab.nix`
- Modify: `users/kyandesutter/linux.nix:6,13`

**Interfaces:**
- Consumes: `inputs.niri.homeModules.niri` (Task 1), `/run/power/state` + `dgpu-reconcile.service` polkit rule (power.nix, unchanged), `aura-repaint` on the home profile (noctalia.nix).
- Produces: `gpu-relog-prompt` binary path (bound in binds), `~/.cache/power-tune/edp-refresh.kdl` + `~/.cache/noctalia/niri-border.kdl` fragment contract (Task 4's template renders the latter), `power-tune` systemd unit.

- [ ] **Step 0 (decision gate): inspect niri-flake's raw-KDL composition.** Before writing the file, read the module source to see how `finalConfig` is derived (guard against infinite recursion when appending raw KDL):

```bash
nix flake metadata github:sodiboo/niri-flake --json | jq -r .path   # or: nix eval --impure --raw --expr '(builtins.getFlake (toString ./.)).inputs.niri.outPath'
rg -n "finalConfig|config =|validated" <that-path>/*.nix | head -40
```
- If `finalConfig` is rendered **from `settings`** (not from `config`): use **Option A** below.
- If `finalConfig` is rendered **from `config`** (recursion risk): use **Option B**.

**Option A (preferred):**
```nix
  programs.niri.config = rawKdlAppendix config.programs.niri.finalConfig;
```
**Option B (fallback):** leave `programs.niri.config` alone and override the emitted file (validation of the appendix then happens at first `niri validate` on login — mitigate by running `nix run nixpkgs#niri -- validate -c <file>` manually in Step 4):
```nix
  xdg.configFile."niri/config.kdl".text = lib.mkForce (rawKdlAppendix config.programs.niri.finalConfig);
```
where in both cases:
```nix
  # recent-windows (native MRU Alt-Tab, niri ≥25.11) and include (≥26.04) are
  # runtime niri features the niri-flake schema has no options for — append
  # them as raw KDL after the typed settings render.
  rawKdlAppendix = rendered: rendered + ''

    // Runtime-mutable fragments (the niri equivalent of `hyprctl eval`):
    // power-tune owns the eDP-1 output block (240↔60Hz refresh flip);
    // Noctalia owns the layout block (wallpaper-derived border colours).
    // optional=true: a missing fragment logs a warning instead of failing.
    include optional=true "~/.cache/power-tune/edp-refresh.kdl"
    include optional=true "~/.cache/noctalia/niri-border.kdl"

    // Native MRU Alt-Tab switcher (replaces the old Quickshell alttab).
    // Hold Alt: Tab cycles forward, Shift+Tab back; release commits,
    // Escape cancels. An explicit binds{} replaces ALL default binds, so
    // Mod+Tab stays free for focus-workspace-previous.
    recent-windows {
        binds {
            Alt+Tab       { next-window; }
            Alt+Shift+Tab { previous-window; }
            Alt+grave     { next-window filter="app-id"; }
        }
    }
  '';
```

- [ ] **Step 1: Create `users/kyandesutter/mixins/niri.nix`** with the full content below. Port the explanatory comments from `hyprland.nix` where the concern survives (power-tune header, monitor layout rationale, workspace split, qt6ct block, PiP notes) — trimmed of Hyprland-specific mechanics. Structure:

```nix
{ pkgs, config, lib, inputs, ... }:
let
  noctaliaBin = "${config.programs.noctalia.package}/bin/noctalia";

  # (port the power-tune header comment from hyprland.nix lines 3-36, with the
  # hyprctl mention replaced by the fragment mechanism)
  powerTune = pkgs.writeShellApplication {
    name = "power-tune";
    runtimeInputs = with pkgs; [
      niri # niri msg
      power-profiles-daemon
      inotify-tools
      dbus
      coreutils
    ];
    text = ''
      source_now() { cat /run/power/state 2>/dev/null || echo battery; }

      profile() {
        powerprofilesctl get 2>/dev/null
      }

      # niri has no runtime per-output IPC; the eDP-1 output block lives in a
      # KDL fragment included from config.kdl (include optional=true), so a
      # refresh flip = rewrite the fragment + ask niri to reload. niri matches
      # the requested refresh to the closest real mode.
      frag_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/power-tune"
      frag="$frag_dir/edp-refresh.kdl"
      set_refresh() {
        if [ "$1" = "$last_rate" ]; then return 0; fi
        mkdir -p "$frag_dir"
        printf 'output "eDP-1" {\n    mode "2560x1600@%s"\n    scale 1.25\n    position x=2560 y=0\n}\n' "$1" > "$frag.tmp"
        mv "$frag.tmp" "$frag"
        niri msg action load-config-file >/dev/null 2>&1 || true
        last_rate="$1"
      }

      reconcile() {
        src="$(source_now)"
        if [ "$src" != "$last_src" ]; then
          colour="$(cat "$HOME/.cache/noctalia/aura-color" 2>/dev/null || echo b15bf5)"
          ${config.home.profileDirectory}/bin/aura-repaint "$colour" || true
          last_src="$src"
        fi
        case "$(profile)" in
          power-saver) set_refresh 60 ;;
          *)           set_refresh 240 ;;
        esac
        ${gpuRelogPrompt}/bin/gpu-relog-prompt &
      }

      /run/current-system/sw/bin/systemctl start dgpu-reconcile.service 2>/dev/null || true

      last_src=""
      last_rate=""
      reconcile
      while read -r line; do
        case "$line" in
          *state*|*PropertiesChanged*|*member=Changed*|*drm*|*DRM*) reconcile ;;
        esac
      done < <( {
        inotifywait -m -q -e close_write,moved_to,create /run/power 2>/dev/null &
        dbus-monitor --system \
          "type='signal',interface='org.freedesktop.DBus.Properties',path='/org/freedesktop/UPower/PowerProfiles'" \
          2>/dev/null &
        /run/current-system/sw/bin/udevadm monitor --udev --subsystem-match=drm 2>/dev/null &
        wait
      } )
    '';
  };

  # Battery-only consent relog prompt. niri hot-adds the dGPU's DRM device at
  # runtime (a monitor on the powered dGPU just works — the old `monitor`
  # branch is gone), but it also opens a renderer fd on every GPU it sees and
  # has no release IPC. So once the dGPU has appeared, `modprobe -r nvidia*`
  # stays blocked until the session ends — on battery that idle dGPU is a
  # large drain, so OFFER (never force) a relog. Dismissals are remembered
  # until the situation changes; Super+Shift+BackSpace is the button fallback.
  gpuRelogPrompt = pkgs.writeShellApplication {
    name = "gpu-relog-prompt";
    runtimeInputs = with pkgs; [ libnotify coreutils util-linux niri ];
    text = ''
      rt="''${XDG_RUNTIME_DIR:-/tmp}"
      confirm="$rt/gpu-relog.confirm"
      dismissed="$rt/gpu-relog.dismissed"
      outfile="$rt/gpu-relog.action"

      if [ "''${1:-}" = confirm ]; then : > "$confirm"; exit 0; fi

      # battery + dGPU DRM device present (niri holds it — the device node
      # only exists while the modules are loaded) + no monitor on any of its
      # connectors → a relog would let dgpu-reconcile power it off.
      evaluate() {
        src=battery
        [ -r /run/power/state ] && src=$(cat /run/power/state)
        card="$(readlink -f /dev/dri/by-path/pci-0000:02:00.0-card 2>/dev/null || true)"
        if [ "$src" != battery ] || [ -z "$card" ]; then echo none; return; fi
        for s in "/sys/class/drm/''${card##*/}"-*/status; do
          [ -e "$s" ] || continue
          if [ "$(cat "$s" 2>/dev/null)" = connected ]; then echo none; return; fi
        done
        echo battery
      }

      need=$(evaluate)
      if [ "$need" = none ]; then
        rm -f "$dismissed"
        exit 0
      fi
      [ -e "$dismissed" ] && exit 0

      exec 9>"$rt/gpu-relog.lock"
      flock -n 9 || exit 0

      rm -f "$confirm" "$outfile"
      notify-send -t 0 -u critical \
        -A relog="Relog now" -A dismiss="Not now" \
        "On battery" "This session holds the dGPU (~10W). Relog to power it off? (Super+Shift+BackSpace also confirms)" \
        > "$outfile" 2>/dev/null &
      np=$!

      act=dismiss
      while :; do
        if [ -e "$confirm" ]; then act=relog; break; fi
        if ! kill -0 "$np" 2>/dev/null; then
          act="$(cat "$outfile" 2>/dev/null || true)"
          [ -n "$act" ] || act=dismiss
          break
        fi
        if [ "$(evaluate)" != "$need" ]; then act=stale; break; fi
        sleep 2
      done
      kill "$np" 2>/dev/null || true
      rm -f "$confirm" "$outfile"

      case "$act" in
        relog) ;;
        stale) exit 0 ;;
        *) : > "$dismissed"; exit 0 ;;
      esac

      [ "$(evaluate)" = "$need" ] || exit 0
      notify-send -t 2000 "GPU mode" "Relogging…" || true
      niri msg action quit --skip-confirmation
    '';
  };

  rawKdlAppendix = /* from Step 0 */;
in
{
  imports = [ inputs.niri.homeModules.niri ];

  programs.niri = {
    enable = true;
    package = pkgs.niri; # nixpkgs 26.04 — also the binary `niri validate` runs
    settings = {
      input = {
        keyboard.xkb = { layout = "es"; options = "caps:escape"; };
        touchpad = {
          tap = true;
          natural-scroll = true;
          click-method = "clickfinger";
          scroll-factor = 0.4;
        };
        # focus-follows-mouse stays off (niri default) — matches follow_mouse=2's
        # "click to focus" half; hovered-scroll works out of the box on niri.
      };

      # Desk monitor at the origin (primary; port the HDMI rationale comment
      # from hyprland.lua). refresh omitted → niri picks the highest rate for
      # the resolution (144), sidestepping exact-float mode matching. VRR off.
      # eDP-1 is deliberately ABSENT here: its output block lives in the
      # power-tune fragment (see rawKdlAppendix) so the refresh flip can own it.
      outputs."HDMI-A-1" = {
        mode = { width = 2560; height = 1440; };
        position = { x = 0; y = 0; };
        scale = 1.0;
        focus-at-startup = true;
      };

      # Named workspaces "1"–"9" (communication 4 + media 8 on the internal
      # panel, the rest on the desk monitor — same split as before).
      workspaces = lib.listToAttrs (map (i: {
        name = toString i;
        value.open-on-output = if i == 4 || i == 8 then "eDP-1" else "HDMI-A-1";
      }) (lib.range 1 9));

      binds = {
        "Mod+Space".action.spawn = [ noctaliaBin "msg" "panel-toggle" "launcher" ];
        "Mod+Return".action.spawn = "ghostty";
        "Mod+Q".action.close-window = [ ];
        "Mod+Shift+F".action.fullscreen-window = [ ];
        "Mod+V".action.toggle-window-floating = [ ];
        "Mod+B".action.spawn = "helium";
        "Mod+ntilde".action.spawn = [ noctaliaBin "msg" "panel-toggle" "clipboard" ];
        "Mod+Period".action.spawn = [ noctaliaBin "msg" "panel-toggle" "launcher" "/emo" ];
        "Mod+Shift+T".action.spawn = [ noctaliaBin "msg" "theme-mode-toggle" ];
        "Mod+Shift+Escape".action.spawn = [ noctaliaBin "msg" "session" "lock-and-suspend" ];
        "Mod+Shift+BackSpace".action.spawn = [ "${gpuRelogPrompt}/bin/gpu-relog-prompt" "confirm" ];

        # Vim-style focus/move mapped onto niri's column model: H/L walk
        # columns, J/K walk windows inside a column.
        "Mod+H".action.focus-column-left = [ ];
        "Mod+J".action.focus-window-down = [ ];
        "Mod+K".action.focus-window-up = [ ];
        "Mod+L".action.focus-column-right = [ ];
        "Mod+Shift+H".action.move-column-left = [ ];
        "Mod+Shift+J".action.move-window-down = [ ];
        "Mod+Shift+K".action.move-window-up = [ ];
        "Mod+Shift+L".action.move-column-right = [ ];

        "Mod+Tab".action.focus-workspace-previous = [ ];

        # niri-native essentials (new — no Hyprland equivalent).
        "Mod+O" = { repeat = false; action.toggle-overview = [ ]; };
        "Mod+F".action.maximize-column = [ ];
        "Mod+M".action.maximize-window-to-edges = [ ];
        "Mod+R".action.switch-preset-column-width = [ ];
        "Mod+Minus".action.set-column-width = "-10%";
        "Mod+Plus".action.set-column-width = "+10%";

        # Screenshots: niri's built-in UI (Print = full screen to file+clipboard,
        # Mod+Shift+S = interactive region picker) replaces the Noctalia tool.
        "Print".action.screenshot-screen = [ ];
        "Mod+Shift+S".action.screenshot = [ ];

        # Volume / brightness / media through noctalia (shared OSD; port the
        # rationale comment from hyprland.lua).
        "XF86AudioRaiseVolume" = { allow-when-locked = true; action.spawn = [ noctaliaBin "msg" "volume-up" ]; };
        "XF86AudioLowerVolume" = { allow-when-locked = true; action.spawn = [ noctaliaBin "msg" "volume-down" ]; };
        "XF86AudioMute".action.spawn = [ noctaliaBin "msg" "volume-mute" ];
        "XF86AudioMicMute".action.spawn = [ noctaliaBin "msg" "mic-mute" ];
        "XF86MonBrightnessUp" = { allow-when-locked = true; action.spawn = [ noctaliaBin "msg" "brightness-up" "current" "10" ]; };
        "XF86MonBrightnessDown" = { allow-when-locked = true; action.spawn = [ noctaliaBin "msg" "brightness-down" "current" "10" ]; };
        "XF86AudioPlay".action.spawn = [ noctaliaBin "msg" "media" "toggle" ];
        "XF86AudioPause".action.spawn = [ noctaliaBin "msg" "media" "toggle" ];
        "XF86AudioNext".action.spawn = [ noctaliaBin "msg" "media" "next" ];
        "XF86AudioPrev".action.spawn = [ noctaliaBin "msg" "media" "previous" ];
        "XF86AudioStop".action.spawn = [ noctaliaBin "msg" "media" "stop" ];
      } // (lib.listToAttrs (lib.concatMap (i: [
        { name = "Mod+${toString i}"; value.action.focus-workspace = toString i; }
        { name = "Mod+Shift+${toString i}"; value.action.move-column-to-workspace = toString i; }
      ]) (lib.range 1 9)));

      # App → workspace pinning (port the class-regex notes from hyprland.lua;
      # niri matches on app-id). Ghostty deliberately has no rule.
      window-rules = [
        { matches = [ { app-id = "^([Hh]elium)$"; } ]; open-on-workspace = "1"; }
        { matches = [ { app-id = "^([Cc]ode|[Zz]ed|dev.zed.Zed)$"; } ]; open-on-workspace = "3"; }
        { matches = [ { app-id = "^([Ss]lack|WhatsApp|[Ee]quibop|discord|[Bb]eeper|[Bb]lue[Bb]ubbles)$"; } ]; open-on-workspace = "4"; }
        # Beeper/BlueBubbles map floating; force them into the layout.
        { matches = [ { app-id = "^([Bb]eeper)$"; } ]; open-floating = false; }
        { matches = [ { app-id = "^([Bb]lue[Bb]ubbles)$"; } ]; open-floating = false; }
        { matches = [ { app-id = "^([Cc]laude)$"; } ]; open-on-workspace = "7"; }
        { matches = [ { app-id = "^([Ss]potify)$"; } ]; open-on-workspace = "8"; }
        { matches = [ { app-id = "^([Ss]team|steam)$"; } ]; open-on-workspace = "9"; }
        # PiP / Chromium popups float (niri has no cross-workspace pin —
        # accepted loss vs Hyprland's `pin`).
        { matches = [ { title = "^([Pp]icture[ -][Ii]n[ -][Pp]icture)$"; } ]; open-floating = true; }
        { matches = [ { app-id = "^$"; title = "^$"; } ]; open-floating = true; }
        { matches = [ { app-id = "^(org.gnome.NautilusPreviewer)$"; } ]; open-floating = true; }
        # Noctalia's own settings window.
        { matches = [ { app-id = "^dev\\.noctalia\\.Noctalia$"; } ]; open-floating = true; }
      ];

      # Noctalia wallpaper/backdrop render inside the overview backdrop.
      layer-rules = [
        { matches = [ { namespace = "^noctalia-wallpaper"; } ]; place-within-backdrop = true; }
        { matches = [ { namespace = "^noctalia-backdrop"; } ]; place-within-backdrop = true; }
      ];

      # layout {} is deliberately ABSENT: the Noctalia border fragment owns it
      # (gaps 0, 2px borders in wallpaper colours — see rawKdlAppendix and
      # noctalia-templates/niri-border.kdl.tmpl).

      environment = {
        QS_ICON_THEME = "Colloid-Dark";
        QT_QPA_PLATFORMTHEME = "qt6ct";
        "__GL_GSYNC_ALLOWED" = "1";
        # iGPU pins, formerly computed by uwsm/env-hyprland: the session is
        # iGPU-primary always, so these are static now. They keep Chromium/
        # Electron/VA-API off the nvidia stack (offloaded apps re-expand the
        # vendor list themselves).
        LIBVA_DRIVER_NAME = "iHD";
        "__EGL_VENDOR_LIBRARY_FILENAMES" = "/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json";
        VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
        VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
      };

      cursor = { theme = "Bibata-Modern-Classic"; size = 24; };
      prefer-no-csd = true;
      hotkey-overlay.skip-at-startup = true;
    };

    config = /* Option A or B from Step 0 */;
  };

  # Seed the runtime fragments so first login (before Noctalia's first render /
  # power-tune's first flip) has sane defaults: 240Hz, Catppuccin Mocha borders
  # (mauve active / surface2 inactive — same fallback as the old general.col).
  # Only-if-absent: both files are runtime-owned after that.
  home.activation.seedNiriFragments = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    frag="$HOME/.cache/power-tune/edp-refresh.kdl"
    if [ ! -e "$frag" ]; then
      run mkdir -p "$HOME/.cache/power-tune"
      run sh -c 'printf "output \"eDP-1\" {\n    mode \"2560x1600@240\"\n    scale 1.25\n    position x=2560 y=0\n}\n" > '"$frag"
    fi
    border="$HOME/.cache/noctalia/niri-border.kdl"
    if [ ! -e "$border" ]; then
      run mkdir -p "$HOME/.cache/noctalia"
      run sh -c 'cat > '"$border"' <<"EOF"
layout {
    gaps 0
    focus-ring {
        off
    }
    border {
        width 2
        active-color "#cba6f7"
        inactive-color "#585b70"
    }
}
EOF'
    fi
  '';

  # power-tune: same unit as before; NIRI_SOCKET reaches it via niri-session's
  # environment import into the systemd user manager (the HYPRLAND_INSTANCE_
  # SIGNATURE pattern, one compositor over).
  systemd.user.services.power-tune = {
    Unit = {
      Description = "Refresh rate + keyboard aura + relog consent prompt follow the power source";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${powerTune}/bin/power-tune";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # GUI polkit agent (hyprpolkitagent replacement; generic Qt agent).
  systemd.user.services.polkit-agent = {
    Unit = {
      Description = "polkit-kde authentication agent";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # (port the qt6ct/QS_ICON_THEME explanation comment from hyprland.nix — the
  # env vars now live in programs.niri.settings.environment above)

  home.packages = with pkgs; [
    wl-clip-persist
    adw-gtk3
    colloid-icon-theme
    adwaita-icon-theme
    kdePackages.qt6ct
    libsForQt5.qt5ct
  ];

  # Cursor (Bibata Modern Classic) — gtk + X11/XWayland; native Wayland reads
  # it from settings.cursor above. hyprcursor is gone with Hyprland.
  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # (port the gtk/dark-mode block from hyprland.nix lines 907-939 verbatim)
  gtk = {
    enable = true;
    iconTheme = {
      name = "Colloid-Dark";
      package = pkgs.colloid-icon-theme;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };
}
```

Verify the polkit agent path first: `ls "$(nix build --no-link --print-out-paths nixpkgs#kdePackages.polkit-kde-agent-1 2>/dev/null || nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.x86_64-linux.kdePackages.polkit-kde-agent-1.outPath')/libexec/"` — adjust `ExecStart` if the binary name differs.

- [ ] **Step 2: Rewire linux.nix** — in `users/kyandesutter/linux.nix`: replace `./mixins/hyprland.nix` with `./mixins/niri.nix`, delete the `./mixins/alttab.nix` line, update the header comment ("Hyprland desktop" → "niri desktop"). `git rm users/kyandesutter/mixins/hyprland.nix users/kyandesutter/mixins/alttab.nix`.

- [ ] **Step 3: Eval** — `git add -A && nix eval '.#nixosConfigurations.g815.config.system.stateVersion'`
Expected: passes (home config not yet forced; the real proof is the Task 6 build).

- [ ] **Step 4: Build the home config early** (this is where `niri validate` runs — catch schema errors NOW, not in Task 6):

```bash
nixos-rebuild build --flake .#g815 2>&1 | tail -20
```
Expected: build succeeds. If it fails on a settings option name, fix against the schema reference in the plan header / niri-flake docs.md; if it fails with infinite recursion, switch to Option B from Step 0. If Option B is in use, additionally validate the final file from the build result manually with `niri validate -c`.

- [ ] **Step 5: Commit** — `git commit -m "feat(niri): user-side niri config replacing hyprland + alttab"`

---

### Task 4: Noctalia re-targeting (border template, flexoki check, alttab removal)

**Files:**
- Create: `users/kyandesutter/noctalia-templates/niri-border.kdl.tmpl`
- Delete: `users/kyandesutter/noctalia-templates/hypr-border.tmpl`, `users/kyandesutter/noctalia-templates/alttab.json.tmpl`
- Modify: `users/kyandesutter/mixins/noctalia.nix` (flexokiScheme ~69-93, templates ~505-530, sources ~630-638)

**Interfaces:**
- Consumes: the `~/.cache/noctalia/niri-border.kdl` include contract from Task 3.
- Produces: rendered `niri-border.kdl` + `niri msg action load-config-file` post_hook.

- [ ] **Step 1: Create `users/kyandesutter/noctalia-templates/niri-border.kdl.tmpl`:**

```
// Generated by Noctalia on every palette change (wallpaper pick / light-dark
// flip). Included from niri's config.kdl (include optional=true) — this
// fragment is the SOLE owner of the layout block; the typed settings in
// mixins/niri.nix deliberately don't declare one. The post_hook in
// mixins/noctalia.nix reloads niri's config so the colours apply instantly.
// primary = active border; error = urgent; surface = inactive.
layout {
    gaps 0
    focus-ring {
        off
    }
    border {
        width 2
        active-color "#{{ colors.primary.default.hex_stripped }}"
        inactive-color "#{{ colors.surface.default.hex_stripped }}"
        urgent-color "#{{ colors.error.default.hex_stripped }}"
    }
}
```

- [ ] **Step 2: Update `users/kyandesutter/mixins/noctalia.nix`:**
  - `flexokiScheme` (lines 69-93): `runtimeInputs = [ config.programs.noctalia.package pkgs.niri pkgs.jq ];` and replace the hyprctl connectivity check with:

```bash
      if [[ -n "$conn" ]]; then
        outs="$(niri msg --json outputs 2>/dev/null || true)"
        # Skip only when we actually got an output map and this connector isn't
        # in it (disconnected). Empty output = niri unreachable → proceed.
        if [[ -n "$outs" ]] && ! jq -e --arg c "$conn" 'has($c)' <<<"$outs" >/dev/null 2>&1; then
          exit 0
        fi
      fi
```
  Update the surrounding comment (lines 60-68): connectivity now via `niri msg --json outputs` / `NIRI_SOCKET` (present in the session env).
  - Replace the `hyprland-border` template block (lines 505-518) with (update the preceding comment: the live push is now a config reload picking up this fragment — one mechanism, no separate eval):

```nix
            niri-border = {
              enabled = true;
              input_path = "~/.config/noctalia/templates/niri-border.kdl.tmpl";
              output_path = "~/.cache/noctalia/niri-border.kdl";
              post_hook = "${lib.getExe pkgs.niri} msg action load-config-file";
            };
```
  (Add `lib` to the module args if not already present.)
  - Delete the `alttab` template block (lines 520-529).
  - In the `xdg.configFile` sources block (630-638): drop the `hypr-border.tmpl` and `alttab.json.tmpl` lines, add `"noctalia/templates/niri-border.kdl.tmpl".source = ../noctalia-templates/niri-border.kdl.tmpl;`.
  - `git rm users/kyandesutter/noctalia-templates/hypr-border.tmpl users/kyandesutter/noctalia-templates/alttab.json.tmpl`

- [ ] **Step 3: Verify + commit**

```bash
git add -A && nixos-rebuild build --flake .#g815 2>&1 | tail -5
rg -il "hypr" --glob '!docs/**' --glob '!*.md' .   # expect: NO hits outside docs
```
Commit: `git commit -m "feat(niri): retarget noctalia theming from hyprctl to niri config reload"`

---

### Task 5: Docs + comment sweep

**Files:**
- Delete: `docs/hyprland-lua.md`
- Modify: `CLAUDE.md` (power section + theming + autostart + overview), `README.md` (g815 description), comment-only touch-ups in `modules/nixos/mixins/nvidia.nix:70,101`, `users/kyandesutter/mixins/qt.nix:9`, `users/kyandesutter/mixins/helium.nix:40`, `users/kyandesutter/mixins/autostart.nix:24-28`, `users/kyandesutter/mixins/desktop-apps.nix:3,31`, `users/kyandesutter/mixins/webapps.nix:51`, `modules/nixos/mixins/locale.nix:16-17`, `modules/nixos/mixins/phone-integration.nix:25`

- [ ] **Step 1: `git rm docs/hyprland-lua.md`** (Hyprland Lua API doc — obsolete).

- [ ] **Step 2: CLAUDE.md** — update the g815 overview line ("Hyprland + Noctalia" → "niri + Noctalia"), the theming section (hypr-border → niri-border fragment; "Hyprland's pre-palette border colours (`general.col`)" → "niri's pre-palette border colours (seeded `niri-border.kdl` fragment)"; drop "the alt-tab switcher's build-time fallback"), the **Power management** section: replace the `hyprland.nix` bullet with the niri model — `power-tune` (aura, refresh via the `edp-refresh.kdl` fragment + config reload, dgpu-reconcile kick), `gpu-relog-prompt` (battery-only: niri hot-adds the dGPU but holds its fd, so the consent prompt remains the only release path), no `env-hyprland`/marker (iGPU-primary is niri's default), fragments mechanism (`include optional=true` + `niri msg action load-config-file`). Update the Autostart section ("Hyprland-coupled startup" list is gone — polkit agent and power-tune are plain user services now; alttab/session-restore/snapshot deleted). Keep the DO-NOT-BREAK framing verbatim.

- [ ] **Step 3: README.md + comment sweep** — mechanical "Hyprland" → "niri" / "uwsm/env-hyprland" → "programs.niri.settings.environment (mixins/niri.nix)" comment updates at the exact locations listed above. No functional changes; verify with `git diff` that only comments/docs changed in those files.

- [ ] **Step 4: Commit** — `git add -A && git commit -m "docs: update power/theming docs for the niri migration"`

---

### Task 6: Full verification + handoff

- [ ] **Step 1: Final greps** — all must return nothing:

```bash
rg -il "hyprland|hyprctl|uwsm|AQ_DRM|hyprpolkitagent|session-gpu-mode" --glob '!docs/**' --glob '!users/kyandesutter/claude/**' .
rg -l "alttab|session-snapshot|session-restore" --glob '!docs/**' --glob '!users/kyandesutter/claude/**' .
```

- [ ] **Step 2: Both hosts eval, g815 builds**

```bash
nix eval '.#nixosConfigurations.g815.config.system.stateVersion'
nix eval '.#darwinConfigurations.macbook.config.system.stateVersion'
nixos-rebuild build --flake .#g815
git diff --stat HEAD -- modules/nixos/mixins/power.nix   # must be empty
```

- [ ] **Step 3: Hand the switch to the owner** — `sudo nixos-rebuild switch` needs a password; ask the owner to run `! just r` (or `! sudo nixos-rebuild switch --flake ~/.config/nix#g815`), then **log out and pick the "niri" session in SDDM**.

- [ ] **Step 4: First-login checklist** (owner-assisted, from the spec): Noctalia bar/wallpaper; workspaces pinned per output; autostart apps land on 1/4/8/9; native Alt+Tab; Print / Mod+Shift+S screenshots; volume/brightness keys; Steam launches (X11 via xwayland-satellite — check `journalctl --user-unit=niri -b | grep -i x11`); `niri msg --json outputs` sane; PPD profile flip changes eDP refresh (check `niri msg outputs` after `powerprofilesctl set power-saver`); wallpaper change recolours borders; on AC → nvidia loads → HDMI lights up live; unplug on battery → relog notification appears.

- [ ] **Step 5: Memory bank** — update the `nix-power-and-theming` auto-memory (env-hyprland/marker gone, battery-only relog, fragment mechanism) and mark the migration done in the spec status line.
