{ pkgs, lib, ... }:
let
  # Clipboard-history picker: cliphist holds the history (populated by the
  # wl-paste watchers in the autostart block below), fuzzel renders it as a
  # dmenu, and the chosen entry is decoded back onto the regular clipboard.
  # Bound to SUPER+ñ. `cliphist decode` restores the original bytes (incl.
  # images) for the id fuzzel returns.
  clipboardPicker = pkgs.writeShellApplication {
    name = "clipboard-picker";
    runtimeInputs = with pkgs; [ cliphist fuzzel wl-clipboard ];
    text = ''
      cliphist list \
        | fuzzel --dmenu --prompt "clip > " \
        | cliphist decode \
        | wl-copy
    '';
  };

  # Cursor-aware brightness control. Adjusts whichever monitor the cursor is
  # currently over: the internal panel via the kernel backlight (brightnessctl),
  # external monitors via DDC/CI (ddcutil). External monitors are addressed by
  # mapping the Hyprland connector name (e.g. HDMI-A-1) to its /dev/i2c-N bus,
  # since ddcutil's own display numbering doesn't track Hyprland's.
  monitorBrightness = pkgs.writeShellApplication {
    name = "monitor-brightness";
    runtimeInputs = with pkgs; [
      hyprland # hyprctl
      jq
      gawk
      coreutils # tr
      util-linux # flock
      brightnessctl
      ddcutil
    ];
    text = ''
      # usage: monitor-brightness up|down [stepPercent]
      dir="''${1:?usage: monitor-brightness up|down [step]}"
      step="''${2:-5}"
      cache="''${XDG_RUNTIME_DIR:-/tmp}/ddc-bus.cache"

      # Cursor position in global layout coords ("x, y" → "x y").
      read -r cx cy < <(hyprctl cursorpos 2>/dev/null | tr -d ',') || true
      if [ -z "''${cx:-}" ] || [ -z "''${cy:-}" ]; then exit 0; fi

      # The monitor whose logical rectangle contains the cursor. width/height are
      # physical pixels, so divide by scale to get the logical size that cursorpos
      # is expressed in.
      mon=$(hyprctl -j monitors | jq -c --argjson cx "$cx" --argjson cy "$cy" '
        first(.[] | select(
          $cx >= .x and $cx < (.x + (.width / .scale)) and
          $cy >= .y and $cy < (.y + (.height / .scale))
        )) // empty') || true
      # Fallback: the focused monitor (used only when the cursor isn't inside
      # any monitor rect; with follow_mouse=0 focus follows clicks, not hover).
      if [ -z "$mon" ]; then
        mon=$(hyprctl -j monitors | jq -c 'first(.[] | select(.focused)) // empty') || true
      fi
      if [ -z "$mon" ]; then exit 0; fi

      name=$(jq -r '.name'          <<<"$mon")
      model=$(jq -r '.model // ""'  <<<"$mon")
      serial=$(jq -r '.serial // ""' <<<"$mon")

      # Internal panel → kernel backlight.
      case "$name" in
        eDP-*|LVDS-*|DSI-*)
          if [ "$dir" = up ]; then
            brightnessctl set "$step%+" >/dev/null || true
          else
            brightnessctl set "$step%-" >/dev/null || true
          fi
          exit 0
          ;;
      esac

      # External monitor → DDC/CI. Build a connector→bus table from `ddcutil
      # detect` (slow, so cache it for the session), keyed by DRM connector with
      # EDID serial then model as fallbacks.
      build_cache() {
        ddcutil detect --terse 2>/dev/null | awk '
          function flush() {
            if (bus != "") printf "%s|%s|%s|%s\n", drm, bus, model, serial
            drm=""; bus=""; model=""; serial=""
          }
          /^Display/       { flush() }
          /I2C bus:/       { b=$0; sub(/.*i2c-/, "", b); bus=b }
          /DRM connector:/ { d=$NF; sub(/^card[0-9]+-/, "", d); drm=d }
          /Model:/         { m=$0; sub(/^[^:]*:[ \t]*/, "", m); model=m }
          /Serial number:/ { s=$0; sub(/^[^:]*:[ \t]*/, "", s); serial=s }
          END              { flush() }
        ' >"$cache" || true
      }

      lookup_bus() {
        [ -s "$cache" ] || return 1
        local b
        b=$(awk -F'|' -v c="$name" '$1==c{print $2; exit}' "$cache")
        if [ -n "$b" ]; then printf '%s\n' "$b"; return 0; fi
        if [ -n "$serial" ]; then
          b=$(awk -F'|' -v s="$serial" '$4==s{print $2; exit}' "$cache")
          if [ -n "$b" ]; then printf '%s\n' "$b"; return 0; fi
        fi
        if [ -n "$model" ]; then
          b=$(awk -F'|' -v m="$model" '$3==m{print $2; exit}' "$cache")
          if [ -n "$b" ]; then printf '%s\n' "$b"; return 0; fi
        fi
        return 1
      }

      bus=$(lookup_bus) || true
      if [ -z "$bus" ]; then build_cache; bus=$(lookup_bus) || true; fi
      if [ -z "$bus" ]; then exit 0; fi

      # Holding the key fires many events, but each DDC write takes ~100ms on the
      # i2c bus. flock -n drops overlapping events so they don't pile up; the
      # monitor visibly changing is the feedback.
      lock="''${XDG_RUNTIME_DIR:-/tmp}/ddc-brightness.lock"
      exec 9>"$lock"
      flock -n 9 || exit 0

      if [ "$dir" = up ]; then
        ddcutil --bus="$bus" --noverify setvcp 10 + "$step" >/dev/null 2>&1 || true
      else
        ddcutil --bus="$bus" --noverify setvcp 10 - "$step" >/dev/null 2>&1 || true
      fi
    '';
  };
in
{
  # Hyprland is enabled at the system level (programs.hyprland in
  # modules/nixos/mixins/hyprland.nix); here we only manage the user config.
  #
  # Hyprland 0.55 dropped the hyprlang (INI-style) `hyprland.conf` in favour of
  # a Lua config at ~/.config/hypr/hyprland.lua (the old syntax is removed, not
  # just deprecated). home-manager's `wayland.windowManager.hyprland.settings`
  # still serialises the old hyprlang syntax ($mod = SUPER, bind = …), which a
  # Lua parser rejects ("<name> expected near '$'"). Until home-manager grows a
  # Lua generator we write hyprland.lua ourselves and skip the HM module so it
  # doesn't emit a conflicting/ignored file.
  #
  # API reference: https://wiki.hypr.land/Configuring/  (Lua: hl.config,
  # hl.monitor, hl.env, hl.bind, hl.dsp.*, hl.window_rule, hl.on).
  xdg.configFile."hypr/hyprland.lua".text = ''
    -- — Monitors —
    -- Desk monitor: ASUS PA278CGV (1440p144) wired to the dGPU. Its EDID-preferred
    -- timing is 60Hz, so pin the 144Hz mode explicitly. Placed at the ORIGIN (0x0) so
    -- it is the *primary* display. This matters for fullscreen games that have no
    -- monitor selector (e.g. Forza Horizon): they target the monitor at (0,0) and
    -- enumerate only its modes. With eDP-1 at the origin, Forza fullscreened onto the
    -- internal panel and locked to its 240Hz/2560x1600 instead of this 1440p144 panel.
    hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@144", position = "0x0", scale = 1.0 })
    -- Internal 18" WQXGA 240Hz panel, to the RIGHT of the desk monitor (same physical
    -- arrangement as before, just shifted so HDMI-A-1 owns the origin). HDMI-A-1 is
    -- 2560px wide at scale 1.0 → this sits at x = 2560. Adjust scale to taste (1.0–1.5).
    hl.monitor({ output = "eDP-1", mode = "2560x1600@240", position = "2560x0", scale = 1.25 })
    -- Catch-all: any other external display at its highest refresh rate ("preferred"
    -- picks the EDID-preferred timing, which is usually 60Hz; "highrr" forces
    -- the panel's max refresh — e.g. 144Hz). Placed to the right of eDP-1.
    hl.monitor({ output = "", mode = "highrr", position = "auto", scale = 1.0 })

    -- — Workspace → monitor binding —
    -- Distribute the nine named workspaces across the two monitors, mirroring the
    -- macOS/aerospace `workspace-to-monitor-force-assignment`: communication (4)
    -- and media (8) live on the internal panel (eDP-1); the other seven (web,
    -- terminal, development, productivity, print, ai, gaming) live on the desk
    -- monitor (HDMI-A-1). Each monitor gets one `default` workspace shown when it
    -- comes up (ws1 on HDMI-A-1, ws4 on eDP-1). When HDMI-A-1 is absent, Hyprland
    -- relocates its workspaces to eDP-1 automatically and moves them back on
    -- reconnect; the eDP-1 assignments keep 4/8 on the internal panel whenever
    -- both displays are present.
    local internalWorkspaces = { [4] = true, [8] = true }
    for i = 1, 9 do
      local monitor = internalWorkspaces[i] and "eDP-1" or "HDMI-A-1"
      hl.workspace_rule({ workspace = tostring(i), monitor = monitor, default = (i == 1 or i == 4) })
    end

    -- — Variables —
    local mod = "SUPER"        -- primary modifier (the physical Cmd-position key)
    local terminal = "ghostty"

    -- — Environment —
    -- Cursor theme/size for XWayland (X11) clients — without XCURSOR_THEME they
    -- fall back to a default theme and show a *different* cursor than native
    -- Wayland apps (which read it from home.pointerCursor / hyprcursor below).
    hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
    hl.env("XCURSOR_SIZE", "24")
    -- NVIDIA + Wayland hints (explicit-sync is automatic on recent drivers).
    hl.env("__GL_GSYNC_ALLOWED", "1")

    -- — Autostart (replaces exec-once) —
    -- caelestia shell auto-starts via its systemd user service. A polkit agent
    -- is needed for GUI auth prompts.
    hl.on("hyprland.start", function()
      hl.exec_cmd("systemctl --user start hyprpolkitagent")
      -- Clipboard manager. Two cliphist watchers record history (text + images);
      -- wl-clip-persist takes ownership of the regular clipboard so its contents
      -- survive the source app closing (Wayland otherwise drops a selection when
      -- the app that offered it exits). Browse the history with SUPER+ñ.
      hl.exec_cmd("wl-paste --type text --watch cliphist store")
      hl.exec_cmd("wl-paste --type image --watch cliphist store")
      hl.exec_cmd("wl-clip-persist --clipboard regular")
      -- Always-running apps on this host: launch minimized to the tray so they
      -- don't grab focus at login. Window rules send steam to workspace 9 (gaming,
      -- HDMI-A-1) and equibop to workspace 4 (communication, eDP-1).
      hl.exec_cmd("steam -silent")
      hl.exec_cmd("equibop --start-minimized")
      -- The rest of the always-open set on this host: the browser, the two
      -- messaging clients, and the music player. None take a "start minimized"
      -- flag like steam/equibop, but each has a window_rule below pinning it to
      -- its named workspace (helium→1 web, beeper & bluebubbles→4 communication,
      -- spotify→8 media), so they open straight onto their own workspace instead
      -- of piling onto whatever is focused at login.
      hl.exec_cmd("helium")
      hl.exec_cmd("beeper")
      hl.exec_cmd("bluebubbles")
      hl.exec_cmd("spotify")
      -- Alt-Tab window switcher (standalone Quickshell instance; config in
      -- users/kyandesutter/mixins/alttab.nix). Started here rather than via a
      -- systemd unit so it inherits Hyprland's Wayland env. It registers the
      -- alttab:next / alttab:prev global shortcuts driven by the binds below.
      -- Guarded with pgrep so a re-fire of hyprland.start (restart-without-
      -- logout, manual relaunch, crash recovery) can't stack duplicate
      -- instances — each would re-register the global shortcuts and keep its
      -- own always-alive Overlay surface + live ScreencopyView captures, which
      -- pegs the compositor on every Alt+Tab (periodic in-game slow-motion).
      -- The `qs` wrapper execs into the `quickshell` binary, so match that in
      -- the running args; the `[q]uickshell` bracket keeps the guard's own
      -- shell (whose argv carries this pattern) from matching itself.
      hl.exec_cmd("pgrep -f '[q]uickshell -c alttab' >/dev/null || ${pkgs.quickshell}/bin/qs -c alttab")
    end)

    -- — General options —
    hl.config({
      input = {
        kb_layout = "es",
        -- Mac keyboards have no AltGr key; map the left Option/Alt (LALT) to the
        -- XKB level-3 selector so it types the es layout's AltGr glyphs
        -- (@ # ~ [ ] { } \ € …). Trade-off: left Alt no longer acts as a plain
        -- Alt modifier (SUPER is the primary mod here anyway).
        kb_options = "lv3:lalt_switch",
        -- 0 = focus only changes on click, never on hover (focus-follows-mouse off).
        follow_mouse = 0,
        sensitivity = 0,
        touchpad = { natural_scroll = true },
      },
      general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        layout = "dwindle",
        resize_on_border = true,
        -- Master switch for screen tearing. Does nothing on its own — a window must
        -- also carry the `immediate` rule (see the game rules below). Used here as a
        -- VRR-free fix for 120fps-into-144Hz judder on the desk monitor; see misc.vrr.
        allow_tearing = true,
      },
      decoration = {
        rounding = 13,
        blur = { enabled = true, size = 6, passes = 3 },
      },
      animations = { enabled = true },
      misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        -- When an app opens a link, the browser requests focus via xdg-activation.
        -- Hyprland ignores activation requests by default (anti-focus-steal), so the
        -- link opens but the browser stays in the background. Honour the request so
        -- the browser window is focused (and its workspace switched to) on open.
        focus_on_activate = true,
        -- VRR is OFF. Games here run ~120fps; on the 240Hz internal panel that's a
        -- clean 2:1 cadence (smooth), but on the fixed 144Hz desk monitor (HDMI-A-1)
        -- 120 doesn't divide 144 — frames are held for 1 or 2 refreshes in an uneven
        -- pattern, which reads as judder at the *same* fps. Rather than adaptive sync,
        -- we fix it with screen tearing: allow_tearing (general, below) + an
        -- `immediate` window rule per game lets fullscreen frames present the instant
        -- they're ready instead of waiting for the 144Hz vblank, killing the judder at
        -- the cost of a visible tear line. direct_scanout (render, below) additionally
        -- hands a fullscreen game's buffer straight to the display plane.
        vrr = 0,
      },
      render = {
        direct_scanout = 1,
      },
      -- eDP-1 runs at fractional scale (1.25). XWayland can't do fractional
      -- scaling, so Hyprland upscales X11 surfaces → blurry/"weird" scaling and
      -- per-frame upscale overhead that drops their framerate. force_zero_scaling
      -- makes XWayland render at scale 1 (crisp, native rate); X11 apps that look
      -- small can be nudged with GDK_SCALE / per-app DPI.
      xwayland = {
        force_zero_scaling = true,
      },
    })

    -- — Keybinds (mirror the macOS/aerospace muscle memory, SUPER as mod) —
    -- App launcher (caelestia registers this Hyprland global shortcut).
    hl.bind(mod .. " + Space", hl.dsp.global("caelestia:launcher"))

    hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
    hl.bind(mod .. " + Q", hl.dsp.window.close())
    hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }))
    hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
    hl.bind(mod .. " + B", hl.dsp.exec_cmd("helium"))
    -- Clipboard history picker (cliphist via fuzzel). ñ is a dedicated key on the
    -- es layout; its XKB keysym is `ntilde`.
    hl.bind(mod .. " + ntilde", hl.dsp.exec_cmd("${clipboardPicker}/bin/clipboard-picker"))
    -- Overnight quiet-download mode: Quiet fan profile + power-saver, blanks the
    -- displays, and holds a Wayland idle-inhibit lock so caelestia's idle daemon
    -- doesn't suspend mid-download. SUPER+SHIFT+N again to restore.
    hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("night-mode toggle"))

    -- Vim-style focus (aerospace alt-hjkl → SUPER+hjkl).
    hl.bind(mod .. " + H", hl.dsp.focus({ direction = "l" }))
    hl.bind(mod .. " + J", hl.dsp.focus({ direction = "d" }))
    hl.bind(mod .. " + K", hl.dsp.focus({ direction = "u" }))
    hl.bind(mod .. " + L", hl.dsp.focus({ direction = "r" }))

    -- Vim-style move (aerospace alt-shift-hjkl → SUPER+SHIFT+hjkl).
    hl.bind(mod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
    hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
    hl.bind(mod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
    hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))

    -- Named workspaces (1=web 2=terminal 3=development 4=communication
    -- 5=productivity 6=print 7=ai 8=media 9=gaming) — matches aerospace.
    for i = 1, 9 do
      hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
      hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i), follow = true }))
    end

    hl.bind(mod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))

    -- Alt-Tab window switcher (Quickshell; config in alttab.nix). The es layout
    -- remaps left Alt to AltGr (lv3:lalt_switch above), which Hyprland sees as the
    -- MOD5 modifier. Hold MOD5 (left Alt) + Tab to open and cycle most-recently-
    -- used windows; release MOD5 to focus the selection. SHIFT reverses. Hyprland
    -- only fires the first press — once open, the Quickshell overlay grabs the
    -- keyboard and handles further Tab / SHIFT+Tab / release itself.
    hl.bind("MOD5 + Tab", hl.dsp.global("alttab:next"))
    hl.bind("MOD5 + SHIFT + Tab", hl.dsp.global("alttab:prev"))

    -- Screenshots (caelestia's integrated tool: saves to ~/Pictures, copies to
    -- the clipboard and shows a notification). Print = whole screen; SUPER+SHIFT+S
    -- = region picker with the screen frozen while you select (macOS Cmd+Shift+4).
    hl.bind("Print", hl.dsp.exec_cmd("caelestia screenshot"))
    hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("caelestia screenshot -r -f"))

    -- Volume / brightness (repeat while held).
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
    -- Brightness adjusts whichever monitor the cursor is on (internal panel via
    -- brightnessctl, external monitors via ddcutil/DDC-CI). See monitorBrightness.
    hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("${monitorBrightness}/bin/monitor-brightness up"), { repeating = true })
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("${monitorBrightness}/bin/monitor-brightness down"), { repeating = true })

    -- Media playback (G815 dedicated keys) via the active MPRIS player.
    hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
    hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"))
    hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))
    hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))
    hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"))

    -- Mouse drag/resize (aerospace SUPER+LMB move, SUPER+RMB resize).
    hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
    hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

    -- — Window → workspace rules (ported from the aerospace setup; Linux app
    --   classes. Verify exact classes on hardware with `hyprctl clients`). —
    -- No `silent`: when one of these apps opens, Hyprland follows the window to
    -- its assigned workspace (add "silent" back to a rule to keep it in the
    -- background instead).
    hl.window_rule({ match = { class = "^([Hh]elium)$" }, workspace = "1" })                       -- web
    hl.window_rule({ match = { class = "^(com.mitchellh.ghostty)$" }, workspace = "2" })           -- terminal
    hl.window_rule({ match = { class = "^([Cc]ode|[Zz]ed|dev.zed.Zed)$" }, workspace = "3" })      -- development
    hl.window_rule({ match = { class = "^([Ss]lack|WhatsApp|[Ee]quibop|discord|[Bb]eeper|[Bb]lue[Bb]ubbles)$" }, workspace = "4" })  -- communication (incl. Discord/equibop/Beeper/BlueBubbles, internal panel)
    -- Beeper (Electron) maps its main window as floating, so it never tiles. Force
    -- it back into the dwindle layout; it still lands on ws4 via the rule above.
    hl.window_rule({ match = { class = "^([Bb]eeper)$" }, float = false })                            -- beeper → tiled
    hl.window_rule({ match = { class = "^([Bb]lue[Bb]ubbles)$" }, float = false })                    -- bluebubbles → tiled
    hl.window_rule({ match = { class = "^([Cc]laude)$" }, workspace = "7" })                       -- ai
    hl.window_rule({ match = { class = "^([Ss]potify)$" }, workspace = "8" })                      -- media
    hl.window_rule({ match = { class = "^([Ss]team|steam)$" }, workspace = "9" })                 -- gaming
    -- Forza Horizon 6 (Steam app 2483190). Must run on XWayland — i.e. launch options
    -- WITHOUT PROTON_ENABLE_WAYLAND (that mode hard-targets output 0 / the internal
    -- panel and Hyprland can't relocate its fullscreen). On XWayland Hyprland controls
    -- the window, so pinning it to ws9 (tied to HDMI-A-1) makes its in-game Fullscreen
    -- land on the external desk monitor while eDP-1 stays active. Launch options:
    --   PROTON_VKD3D_HEAP=1 VKD3D_CONFIG=enable_experimental_features,descriptor_heap %command%
    hl.window_rule({ match = { class = "^(steam_app_2483190)$" }, workspace = "9" })                -- forza → gaming/HDMI
    -- Force fullscreen on map. FH6 restores its last *floating* window geometry,
    -- and a position saved under a previous monitor layout (HDMI-A-1 was at -2560,0)
    -- lands the window off the left edge once HDMI-A-1 owns the 0,0 origin — visible
    -- only as audio. Fullscreening on map snaps it to HDMI-A-1 (0,0..2560) regardless
    -- of the remembered coordinate, so a stale position can never hide it again.
    hl.window_rule({ match = { class = "^(steam_app_2483190)$" }, fullscreen = true })              -- forza → always fullscreen
    -- Allow tearing for Steam games (any steam_app_<id> window). Pairs with
    -- general.allow_tearing to present frames immediately instead of on the 144Hz
    -- vblank — the VRR-free cure for the 120/144 judder on the desk monitor. Tearing
    -- only actually happens when the game itself presents without vsync, so launch
    -- games with vsync OFF (in-game setting, or Vulkan IMMEDIATE / __GL_SYNC_TO_VBLANK=0).
    hl.window_rule({ match = { class = "^(steam_app_.*)$" }, immediate = true })                    -- games → allow tearing
    hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, float = true })                 -- floating PiP
  '';

  # — Multi-GPU primary selection (hybrid laptop) —
  #
  # This G815 is a hybrid laptop: the Intel iGPU (PCI 0000:00:02.0) drives the
  # internal panel (eDP-1), while the NVIDIA dGPU (PCI 0000:02:00.0) drives the
  # external ports — including HDMI-A-1, the 1440p144 desk monitor games run on.
  #
  # By default Hyprland's Aquamarine backend makes the *boot* GPU (the iGPU,
  # which owns fb0) its primary render/allocator device. With both the game and
  # its monitor on the dGPU, every frame then crosses PCIe twice — dGPU renders →
  # copied to the iGPU to composite → copied back to the dGPU to scan out on
  # HDMI-A-1. That starves the dGPU (it stalls on the copies, so it never
  # saturates — "GPU isn't being fully used") and surfaces in games as periodic
  # slow-motion every few seconds — the symptom the disk/alt-tab/VRR/tearing
  # changes were all chasing without addressing the cross-GPU copy itself.
  #
  # AQ_DRM_DEVICES is a ':'-separated device list; the FIRST entry becomes the
  # primary GPU (aquamarine src/backend/drm/DRM.cpp). Listing the dGPU first
  # makes the gaming path zero-copy (game → dGPU → HDMI-A-1 directly); only the
  # iGPU's internal panel then needs a cross-GPU copy.
  #
  # Battery trade-off: a primary dGPU can't RTD3-sleep, which fights the
  # finegrained NVIDIA power management in modules/nixos/mixins/nvidia.nix. So
  # only opt in when a display is actually lit on the dGPU (i.e. docked to the
  # external monitor); undocked, leave AQ_DRM_DEVICES unset so the iGPU stays
  # primary and the dGPU powers down as before. The choice is made ONCE at
  # session start — uwsm sources env-${XDG_CURRENT_DESKTOP,,} (→ env-hyprland)
  # as a POSIX shell script before launching Hyprland — so dock *before* logging
  # in to get the zero-copy path; plugging the monitor in afterwards needs a relog.
  #
  # GPUs are resolved through the stable by-path PCI symlinks (DRM card numbers
  # can reorder across boots) back to the canonical /dev/dri/cardN nodes that
  # aquamarine enumerates and matches against.
  xdg.configFile."uwsm/env-hyprland".text = ''
    dgpu=$(readlink -f /dev/dri/by-path/pci-0000:02:00.0-card 2>/dev/null)
    igpu=$(readlink -f /dev/dri/by-path/pci-0000:00:02.0-card 2>/dev/null)
    if [ -n "$dgpu" ] && [ -n "$igpu" ]; then
      card=$(basename "$dgpu")
      for status in /sys/class/drm/"$card"-*/status; do
        [ -r "$status" ] || continue
        if [ "$(cat "$status")" = connected ]; then
          export AQ_DRM_DEVICES="$dgpu:$igpu"
          break
        fi
      done
    fi
  '';

  # — Quickshell icon theme —
  #
  # caelestia (and the alttab switcher in alttab.nix) are Quickshell/Qt6 apps.
  # Their icons come from Qt's icon theme, which Quickshell takes from the Qt
  # *platform theme*. This session sets no Qt platform theme (QT_QPA_PLATFORMTHEME
  # is unset), so Qt's icon theme falls back to a near-empty default and every
  # unresolved icon renders as the magenta/black "missing texture" placeholder —
  # all over caelestia and in alttab. (GTK apps are unaffected: they read
  # gtk-icon-theme-name directly from gtk-3.0/settings.ini.)
  #
  # Papirus-Dark is already installed and named for GTK (the catppuccin module
  # pulls it in and points gtk-icon-theme-name + dconf icon-theme at it when
  # gtk.enable is on). Rather than introduce a full Qt platform theme (which would
  # restyle every Qt app), point Quickshell straight at it with QS_ICON_THEME —
  # Quickshell's own override env var. The scheme is pinned to mocha *dark*
  # (caelestiaScheme), so QS_ICON_THEME not tracking light/dark doesn't matter.
  #
  # Placed in uwsm/env (sourced for every uwsm session and imported into the
  # systemd user manager) so it reaches caelestia.service — a systemd user unit —
  # as well as the Hyprland-spawned alttab instance.
  xdg.configFile."uwsm/env".text = ''
    export QS_ICON_THEME="Papirus-Dark"
  '';

  # Clipboard manager: cliphist (history store), wl-clip-persist (keep the
  # selection alive after the source app exits). The picker UI is fuzzel,
  # configured via programs.fuzzel below. Nautilus is the GUI file manager, plus
  # the GNOME companions that make it feel complete: file-roller (extract/create
  # archives from the right-click menu), sushi (Spacebar quick-preview), and
  # loupe (the GNOME image viewer).
  home.packages = with pkgs; [
    cliphist
    wl-clip-persist
    hyprpolkitagent
    nautilus
    file-roller
    sushi
    loupe

    # GNOME/GTK apps that round out the desktop.
    papers # PDF / document viewer (default for application/pdf)
    gnome-text-editor # plain-text editor (default for text/plain)
    gnome-calendar
    gnome-clocks
    gnome-maps
    snapshot # camera

    # Media + office, so double-clicking these files in Nautilus opens something.
    #   • celluloid: GTK4/libadwaita mpv frontend — plays every common video
    #     format. GNOME Videos (totem) is the "native" app but has weak codec
    #     support; mpv handles everything, so this is the reliable GTK choice.
    #   • libreoffice-fresh: the only real office suite here (GNOME has none).
    #     The -fresh build renders through the gtk3 VCL backend, so it follows
    #     the adw-gtk3-dark theme set below. Opens Word/Excel/PowerPoint + ODF.
    celluloid
    libreoffice-fresh
  ];

  # Default apps by MIME. enable writes ~/.config/mimeapps.list.
  #   • Folders → Nautilus (xdg-open, file pickers, "open containing folder",
  #     caelestia, etc. all launch it).
  #   • Images → Loupe, so double-clicking an image in Nautilus opens it.
  #   • PDFs → Papers; plain text → GNOME Text Editor.
  #   • Video → Celluloid.
  #   • Office docs → the matching LibreOffice component (Writer/Calc/Impress).
  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      {
        "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
        "application/pdf" = [ "org.gnome.Papers.desktop" ];
        "text/plain" = [ "org.gnome.TextEditor.desktop" ];
      }
      // lib.genAttrs [
        "image/png"
        "image/jpeg"
        "image/gif"
        "image/webp"
        "image/bmp"
        "image/tiff"
        "image/x-icon"
        "image/heif"
        "image/avif"
        "image/svg+xml"
      ] (_: [ "org.gnome.Loupe.desktop" ])
      // lib.genAttrs [
        "video/mp4"
        "video/x-matroska" # .mkv
        "video/webm"
        "video/quicktime" # .mov
        "video/x-msvideo" # .avi
        "video/mpeg"
        "video/ogg"
        "video/x-m4v"
        "video/3gpp"
        "video/x-flv"
        "video/x-ms-wmv"
      ] (_: [ "io.github.celluloid_player.Celluloid.desktop" ])
      // lib.genAttrs [
        # Word-processor documents (.doc/.docx/.odt/.rtf) → Writer.
        "application/msword"
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        "application/vnd.oasis.opendocument.text"
        "application/rtf"
      ] (_: [ "writer.desktop" ])
      // lib.genAttrs [
        # Spreadsheets (.xls/.xlsx/.ods/.csv) → Calc.
        "application/vnd.ms-excel"
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        "application/vnd.oasis.opendocument.spreadsheet"
        "text/csv"
      ] (_: [ "calc.desktop" ])
      // lib.genAttrs [
        # Presentations (.ppt/.pptx/.odp) → Impress.
        "application/vnd.ms-powerpoint"
        "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        "application/vnd.oasis.opendocument.presentation"
      ] (_: [ "impress.desktop" ]);
  };

  # Cursor theme — Bibata Modern Ice (https://www.opendesktop.org/p/1197198/).
  # Sets it for GTK, native Wayland (hyprcursor) and X11/XWayland (x11.enable
  # exports XCURSOR_THEME/SIZE) so every app shows the same pretty cursor.
  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
    hyprcursor.enable = true;
  };

  # Dark mode for GTK / X11 / browsers.
  #
  # caelestia already sets the *Wayland* dark signal: the xdg-desktop-portal
  # `org.freedesktop.appearance color-scheme` reports prefer-dark, and dconf
  # `org/gnome/desktop/interface` has color-scheme=prefer-dark + gtk-theme=
  # adw-gtk3-dark. That's enough for native-Wayland libadwaita/GTK4 apps.
  #
  # But two classes of app don't read the portal/dconf and were staying light:
  #   • X11 / XWayland GTK apps — they read XSettings or ~/.config/gtk-3.0/
  #     settings.ini (neither existed here; no xsettingsd is running).
  #   • Browsers running under XWayland — same story, they derive
  #     prefers-color-scheme from the GTK theme.
  # On top of that, `adw-gtk3-dark` was named in dconf but the theme package was
  # never actually installed, so even dconf readers couldn't resolve it.
  #
  # The gtk module fixes both: it installs adw-gtk3 (so the theme resolves) and
  # writes the gtk-3.0/gtk-4.0 settings.ini files with the dark theme and
  # gtk-application-prefer-dark-theme — which is exactly what X11 apps read.
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  # fuzzel is the menu used by the clipboard picker (clipboardPicker above).
  # Themed to match the rest of the desktop: Catppuccin Mocha palette with the
  # Mauve accent, Geist UI font, and the same 13px rounding / mauve border as the
  # Hyprland window decorations. Colours are RRGGBBAA hex.
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "Geist:size=12";
        lines = 12;
        width = 50;
      };
      colors = {
        background = "1e1e2eff"; # base
        text = "cdd6f4ff"; # text
        match = "cba6f7ff"; # mauve
        selection = "585b70ff"; # surface2
        selection-text = "cdd6f4ff";
        selection-match = "cba6f7ff";
        border = "cba6f7ff"; # mauve
      };
      border = {
        radius = 13;
        width = 2;
      };
    };
  };
}
