{ pkgs, config, ... }:
let
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
  # Power-source-aware refresh rate + keyboard aura + dGPU dock-relog (see
  # systemd.user.services.power-tune).
  #
  # Subscribes to /run/power/state — published by the system reconciler in
  # modules/nixos/mixins/asus.nix, the single authority on the power source
  # (ac / powerbank / battery). A power bank reports as ADP0=online to UPower, so
  # we deliberately do NOT use UPower's OnBattery here; the state file is what
  # tells a ~50W power bank apart from the ~300W barrel.
  #
  # This owns only the *session* side (the power profile itself is owned by the
  # system reconciler):
  #   - keyboard aura: delegated to aura-repaint (the shared single setter, see
  #     noctalia.nix), passing the cached wallpaper accent. ac=static,
  #     powerbank=breathe ("charging" vibe), battery=dark.
  #   - refresh rate: eDP-1 is 2560x1600@240Hz; drop to 60Hz whenever the active
  #     PPD profile is power-saver, restore 240Hz otherwise. Refresh follows the
  #     *profile* (not the source) so a manual Noctalia power-saver toggle also
  #     drops to 60Hz. Mode is set via `hyprctl eval` (the Lua parser rejects
  #     `hyprctl keyword`).
  #   - dGPU dock-relog: only on a transition *to* ac (barrel plugged) — never for
  #     a power bank. dock-relog self-guards on the session-gpu-mode marker + a 10s
  #     cancel window and ends in `uwsm stop` (or returns if canceled / already
  #     dGPU-primary).
  #
  # Event-driven, no polling: two monitors feed one loop through a single process
  # substitution (which keeps the loop in this shell so last_src/last_rate persist)
  # — inotifywait on /run/power/state for source changes, dbus-monitor on PPD for
  # profile changes (the refresh follow). The inner `wait` keeps the substitution
  # alive while both backgrounded monitors run.
  powerTune = pkgs.writeShellApplication {
    name = "power-tune";
    runtimeInputs = with pkgs; [
      hyprland # hyprctl
      power-profiles-daemon # powerprofilesctl
      inotify-tools # inotifywait
      dbus # dbus-monitor
      coreutils
    ];
    text = ''
      source_now() { cat /run/power/state 2>/dev/null || echo battery; }

      profile() {
        powerprofilesctl get 2>/dev/null
      }

      set_refresh() {
        if [ "$1" = "$last_rate" ]; then return 0; fi
        hyprctl eval \
          "hl.monitor({ output = \"eDP-1\", mode = \"2560x1600@$1\", position = \"2560x0\", scale = 1.25 })" \
          >/dev/null 2>&1 || true
        last_rate="$1"
      }

      reconcile() {
        src="$(source_now)"
        if [ "$src" != "$last_src" ]; then
          # Repaint the keyboard for the new source via the shared setter (in the
          # home profile — user services have a limited PATH, so reference it
          # absolutely), using the cached wallpaper accent (fall back to the seed).
          colour="$(cat "$HOME/.cache/noctalia/aura-color" 2>/dev/null || echo b15bf5)"
          ${config.home.profileDirectory}/bin/aura-repaint "$colour" || true
          # Offer the dGPU relog only when arriving on real AC (barrel) from
          # elsewhere — never on a power bank. Skips the initial reconcile, where
          # last_src is empty.
          if [ "$src" = ac ] && [ -n "$last_src" ]; then
            ${dockRelog}/bin/dock-relog || true
          fi
          last_src="$src"
        fi
        case "$(profile)" in
          power-saver) set_refresh 60 ;;
          *)           set_refresh 240 ;;
        esac
      }

      last_src=""
      last_rate=""
      reconcile
      while read -r line; do
        case "$line" in
          *state*|*PropertiesChanged*|*member=Changed*) reconcile ;;
        esac
      done < <( {
        inotifywait -m -q -e close_write,moved_to,create /run/power 2>/dev/null &
        dbus-monitor --system \
          "type='signal',interface='org.freedesktop.DBus.Properties',path='/org/freedesktop/UPower/PowerProfiles'" \
          2>/dev/null &
        wait
      } )
    '';
  };

  # — Window session snapshot / restore + AC-dock auto-relog —
  #
  # AQ_DRM_DEVICES (the dGPU-primary zero-copy path; see uwsm/env-hyprland below)
  # is read once at aquamarine init, so switching the primary GPU needs a full
  # relog. We want the dGPU primary whenever on AC (desk or travelling — games
  # render on the dGPU and present to whatever panel is lit) and the iGPU primary
  # on battery (so the dGPU can RTD3-sleep). powerTune's reconcile() already fires
  # on the battery→AC edge, so it calls dock-relog there; env-hyprland re-derives
  # the GPU from AC state on the new session; session-restore relaunches the
  # windows the last snapshot recorded. Restore also runs on *manual* relogs, so
  # the snapshot is taken continuously rather than only at relog time.

  # Periodic, game-aware window snapshot. `session-snapshot loop` runs the watcher
  # loop (started from hyprland.start); `session-snapshot` (no arg) writes one
  # snapshot (also called by dock-relog right before tearing the session down).
  # Each window records class/title/workspace/floating + its argv from /proc so
  # restore can relaunch it. While a window is fullscreen (gaming) the tick is
  # skipped entirely — the layout isn't changing, so steady-state game cost ≈ 0.
  sessionSnapshot = pkgs.writeShellApplication {
    name = "session-snapshot";
    runtimeInputs = with pkgs; [ hyprland jq coreutils ];
    text = ''
      if [ "''${1:-}" = loop ]; then
        while true; do
          "$0" >/dev/null 2>&1 || true
          sleep 20
        done
      fi

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-session"
      mkdir -p "$state_dir"
      out="$state_dir/windows.json"
      tmp="$out.tmp"
      parts="$out.parts"

      # Game-aware skip: don't poke the compositor while a window is fullscreen.
      fs=$(hyprctl -j activewindow 2>/dev/null | jq -r '.fullscreen // 0') || fs=0
      [ -n "$fs" ] || fs=0
      if [ "$fs" != 0 ]; then exit 0; fi

      clients=$(hyprctl -j clients 2>/dev/null) || exit 0
      [ -n "$clients" ] || exit 0
      addrs=$(jq -r '.[].address' <<<"$clients" 2>/dev/null) || exit 0

      : > "$parts"
      while IFS= read -r addr; do
        [ -n "$addr" ] || continue
        win=$(jq -c --arg a "$addr" 'first(.[] | select(.address==$a)) // empty' <<<"$clients") || continue
        [ -n "$win" ] || continue

        pid=$(jq -r '.pid // empty' <<<"$win")
        case "$pid" in *[!0-9]*) pid="" ;; esac

        cmd_json="[]"
        if [ -n "$pid" ] && [ -r "/proc/$pid/cmdline" ]; then
          cmd_json=$(tr '\0' '\n' < "/proc/$pid/cmdline" | jq -Rn '[inputs]' 2>/dev/null) || cmd_json="[]"
          [ -n "$cmd_json" ] || cmd_json="[]"
        fi

        jq -c --argjson cmd "$cmd_json" \
          '{class: .class, title: .title, workspace: .workspace.id, floating: .floating, cmd: $cmd}' \
          <<<"$win" >> "$parts" || true
      done <<<"$addrs"

      if jq -s '.' "$parts" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$out"
      fi
      rm -f "$parts" "$tmp"
    '';
  };

  # Relaunch the windows recorded in the last snapshot and place each on the
  # workspace it was on. Runs on every hyprland.start (AC-triggered or manual
  # relog). Skips the autostart set (hyprland.start owns those) and shell surfaces,
  # and dedupes per class against what's already open, so it's idempotent — a
  # restart-without-logout won't duplicate anything. Only workspace + floating
  # state are restored (in-app state can't survive a relog).
  sessionRestore = pkgs.writeShellApplication {
    name = "session-restore";
    runtimeInputs = with pkgs; [ hyprland jq coreutils ];
    text = ''
      state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-session/windows.json"
      [ -r "$state_file" ] || exit 0
      snap=$(<"$state_file") || exit 0
      [ -n "$snap" ] || exit 0

      # Autostart owns these (hyprland.start), and shell surfaces aren't apps —
      # never relaunch them, regardless of whether they're up yet at restore time.
      skip_class() {
        case "$1" in
          [Hh]elium|[Bb]eeper|[Bb]lue[Bb]ubbles|[Ss]potify|[Ss]team|steam_app_*|[Ee]quibop) return 0 ;;
          quickshell|[Nn]octalia*|*[Pp]olkit*|xdg-desktop-portal*) return 0 ;;
          "") return 0 ;;
        esac
        return 1
      }

      open=$(hyprctl -j clients 2>/dev/null) || open='[]'
      [ -n "$open" ] || open='[]'

      classes=$(jq -r '[.[].class] | unique | .[]' <<<"$snap" 2>/dev/null) || exit 0
      while IFS= read -r class; do
        [ -n "$class" ] || continue
        if skip_class "$class"; then continue; fi

        entries=$(jq -c --arg c "$class" '[.[] | select(.class==$c)]' <<<"$snap") || continue
        want=$(jq 'length' <<<"$entries") || want=0
        have=$(jq --arg c "$class" '[.[] | select(.class==$c)] | length' <<<"$open") || have=0

        i="$have"
        while [ "$i" -lt "$want" ]; do
          entry=$(jq -c --argjson i "$i" '.[$i]' <<<"$entries") || break
          i=$((i + 1))

          cmd=$(jq -r '.cmd | map(@sh) | join(" ")' <<<"$entry") || cmd=""
          [ -n "$cmd" ] || continue

          # Stale Nix store path (GC'd after a rebuild) → retry on PATH by basename.
          bin=$(jq -r '.cmd[0] // ""' <<<"$entry") || bin=""
          case "$bin" in
            /*) if [ ! -x "$bin" ]; then
                  base=$(basename "$bin")
                  cmd=$(jq -r --arg b "$base" '([$b] + .cmd[1:]) | map(@sh) | join(" ")' <<<"$entry") || cmd=""
                fi ;;
          esac
          [ -n "$cmd" ] || continue

          ws=$(jq -r '.workspace // ""' <<<"$entry") || ws=""
          floating=$(jq -r '.floating // false' <<<"$entry") || floating=false
          if [ "$ws" -ge 1 ] 2>/dev/null; then
            rule="workspace $ws silent"
          else
            rule="silent"
          fi
          if [ "$floating" = true ]; then rule="$rule; float"; fi

          hyprctl dispatch exec "[$rule] $cmd" >/dev/null 2>&1 || true
        done
      done <<<"$classes"
    '';
  };

  # Guarded relog, called by powerTune on a battery→AC transition. Self-guards on
  # the session-gpu-mode marker (written by env-hyprland) so a session that already
  # booted dGPU-primary is never relogged. Shows a notification with a 10s cancel
  # window (Super+Shift+Backspace → `dock-relog cancel` drops the cancel flag); if
  # not canceled it takes a fresh snapshot and `uwsm stop`s cleanly back to SDDM.
  # On the next login env-hyprland re-derives the (now dGPU) GPU and session-restore
  # relaunches the windows.
  dockRelog = pkgs.writeShellApplication {
    name = "dock-relog";
    runtimeInputs = with pkgs; [ libnotify coreutils uwsm ];
    text = ''
      cancel="''${XDG_RUNTIME_DIR:-/tmp}/dock-relog.cancel"
      marker="''${XDG_RUNTIME_DIR:-/tmp}/session-gpu-mode"

      if [ "''${1:-}" = cancel ]; then
        : > "$cancel"
        notify-send -t 1500 "Docking" "Auto-relog canceled." || true
        exit 0
      fi

      # Only relog when this session booted iGPU-primary; if already dGPU, nothing
      # to do (e.g. plugged in at boot, or a battery→AC→battery→AC bounce).
      mode=igpu
      if [ -r "$marker" ]; then mode=$(cat "$marker"); fi
      if [ "$mode" != igpu ]; then exit 0; fi

      rm -f "$cancel"
      notify-send -t 11000 "Docking" "On AC — relogging in 10s to enable the dGPU. Super+Shift+Backspace to cancel." || true

      i=0
      while [ "$i" -lt 10 ]; do
        if [ -e "$cancel" ]; then rm -f "$cancel"; exit 0; fi
        sleep 1
        i=$((i + 1))
      done
      if [ -e "$cancel" ]; then rm -f "$cancel"; exit 0; fi

      ${sessionSnapshot}/bin/session-snapshot || true
      notify-send -t 2000 "Docking" "Relogging…" || true
      uwsm stop
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
    -- vrr = 1: FreeSync/adaptive-sync always on for this panel (overrides misc.vrr).
    hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@144", position = "0x0", scale = 1.0, vrr = 1 })
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
    -- noctalia shell auto-starts via its systemd user service. A polkit agent
    -- is needed for GUI auth prompts.
    hl.on("hyprland.start", function()
      hl.exec_cmd("systemctl --user start hyprpolkitagent")
      -- Generic GUI login apps (steam, equibop, 1password, helium, beeper,
      -- bluebubbles, spotify, wl-clip-persist) now live as systemd user services
      -- bound to graphical-session.target in users/kyandesutter/mixins/autostart.nix.
      -- Window rules below still pin each one to its named workspace.
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
      -- Window session restore + snapshotting (see the session/dock scripts in the
      -- let block and the AC-keyed GPU choice in uwsm/env-hyprland below). Restore
      -- relaunches the windows from the last snapshot onto their workspaces; it
      -- skips the autostart set above and dedupes against what's already open, so a
      -- restart-without-logout won't duplicate anything. The snapshot loop keeps the
      -- state fresh (game-aware: it skips while a window is fullscreen) so *manual*
      -- relogs restore too. The AC-plug relog itself is driven by powerTune (above),
      -- not here. pgrep-guarded like the alttab launcher so re-fires can't stack it.
      hl.exec_cmd("${sessionRestore}/bin/session-restore")
      hl.exec_cmd("pgrep -f '[s]ession-snapshot loop' >/dev/null || ${sessionSnapshot}/bin/session-snapshot loop")
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
        -- Static Catppuccin Mocha fallback for the borders (mauve active / surface2
        -- inactive). Noctalia overrides these with the live wallpaper palette — both
        -- instantly via `hyprctl eval` (mixins/noctalia.nix post_hook) and
        -- persistently via the dofile below. Without a value here Hyprland's built-in
        -- default active border is white, which is what borders revert to whenever a
        -- `hyprctl reload`/startup re-evals this config before the palette is applied.
        col = {
          active_border = "rgb(cba6f7)",
          inactive_border = "rgb(585b70)",
        },
        -- Master switch for screen tearing. Does nothing on its own — a window must
        -- also carry the `immediate` rule (see the game rules below). Kept as an
        -- optional low-latency fullscreen path; the desk monitor's judder is now
        -- handled by per-monitor FreeSync (vrr = 1), see misc.vrr.
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
        -- Global VRR default is OFF; the desk monitor (HDMI-A-1) opts in to
        -- FreeSync per-monitor via its `vrr = 1` above, and the internal eDP-1
        -- panel stays off. (The old judder we blamed on a 120fps-into-144Hz
        -- cadence mismatch turned out to be a GPU hybrid mismatch — now fixed —
        -- so adaptive sync is the right cure rather than the screen-tearing
        -- workaround.) allow_tearing / `immediate` / direct_scanout below remain
        -- available as a low-latency fullscreen path.
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

    -- — Border colours: persist the last wallpaper palette across reloads —
    -- Noctalia renders the live wallpaper-derived border/group colours to
    -- ~/.cache/noctalia/hypr-border on every palette change and also pushes them live
    -- via `hyprctl eval` (mixins/noctalia.nix). That eval is runtime-only, so a
    -- `hyprctl reload` (or the startup race before the first palette render) would
    -- drop back to the static Catppuccin fallback in `general.col` above. Re-applying
    -- the cache file here on every config eval keeps the wallpaper colours instead.
    -- pcall: the file is absent before Noctalia's first render — fall through to the
    -- fallback rather than erroring the whole config.
    pcall(dofile, os.getenv("HOME") .. "/.cache/noctalia/hypr-border")

    -- — Keybinds (mirror the macOS/aerospace muscle memory, SUPER as mod) —
    -- App launcher (noctalia panel toggled over IPC).
    hl.bind(mod .. " + Space", hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))

    hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
    hl.bind(mod .. " + Q", hl.dsp.window.close())
    hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }))
    hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
    hl.bind(mod .. " + B", hl.dsp.exec_cmd("helium"))
    -- Clipboard history (noctalia's dedicated clipboard panel, over IPC). ñ is a
    -- dedicated key on the es layout; its XKB keysym is `ntilde`.
    hl.bind(mod .. " + ntilde", hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard"))
    -- Emoji picker (noctalia's launcher in /emo mode, over IPC).
    hl.bind(mod .. " + period", hl.dsp.exec_cmd("noctalia msg panel-toggle launcher /emo"))
    -- Toggle light/dark mode. noctalia regenerates the wallpaper-derived palette
    -- for the new mode and re-renders every app template (terminal, editor,
    -- Discord, Aura keyboard, GTK/Qt). See mixins/noctalia.nix.
    hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd("noctalia msg theme-mode-toggle"))
    -- Overnight quiet-download mode: Quiet fan profile + power-saver, blanks the
    -- displays, and holds a Wayland idle-inhibit lock so noctalia's idle service
    -- doesn't blank the screen mid-download. SUPER+SHIFT+N again to restore.
    hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("night-mode toggle"))
    -- Sleep: lock then suspend on demand. noctalia's `session lock-and-suspend`
    -- locks the screen before suspending, so resume lands on the lock screen.
    hl.bind(mod .. " + SHIFT + Escape", hl.dsp.exec_cmd("noctalia msg session lock-and-suspend"))
    -- Cancel an in-progress AC-dock auto-relog (the 10s countdown after plugging in
    -- AC). See dockRelog / powerTune in the let block.
    hl.bind(mod .. " + SHIFT + BackSpace", hl.dsp.exec_cmd("${dockRelog}/bin/dock-relog cancel"))

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

    -- Screenshots (noctalia's integrated tool, over IPC). Print = whole screen;
    -- SUPER+SHIFT+S = region picker (macOS Cmd+Shift+4).
    hl.bind("Print", hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen"))
    hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("noctalia msg screenshot-region"))

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
    -- vblank — an optional low-latency path now that the desk monitor uses FreeSync
    -- (vrr = 1) for smooth presentation. Tearing only actually happens when the game
    -- itself presents without vsync, so launch games with vsync OFF (in-game setting,
    -- or Vulkan IMMEDIATE / __GL_SYNC_TO_VBLANK=0).
    hl.window_rule({ match = { class = "^(steam_app_.*)$" }, immediate = true })                    -- games → allow tearing
    -- — Chromium/helium auxiliary popups: float, pin across every workspace, and
    --   tuck into a corner. Mirrors the aerospace setup (float PiP + keep it on the
    --   focused workspace); `pin` is Hyprland's "show on all workspaces". helium
    --   gives these three windows distinct identities, captured live with
    --   `hyprctl clients` + the openwindow event socket:
    --     • Video PiP      → class "" (empty), title "Picture in picture"
    --     • Built-in notif → class "" (empty), title "" (empty)
    --     • Document PiP   → class "helium", maps floating, dynamic page title
    --   Matching is on initialClass/initialTitle (creation-time) — which is why the
    --   old `title:Picture-in-Picture` rule never fired: the real title is
    --   "Picture in picture" (spaces, not hyphens) and the class is empty, not helium.
    --
    -- Video PiP → float, pin, bottom-right, capped to ~28% (it opens ~1240px wide).
    -- Title is distinctive enough to match alone; the char-classes tolerate the
    -- "Picture in picture" / "Picture-in-Picture" spellings and capitalisation.
    hl.window_rule({ match = { title = "^([Pp]icture[ -][Ii]n[ -][Pp]icture)$" },
      float = true, pin = true,
      size = { "monitor_w*0.28", "monitor_h*0.28" },
      move = { "monitor_w-window_w-16", "monitor_h-window_h-16" } })
    -- Document PiP (and any other floating helium popup) → pin + sane size (Meet's
    -- document PiP opens ~1240x1110 — the "massive" one) + bottom-right. Matched on
    -- floating state, so normal *tiled* browser windows are untouched (only the
    -- dynamic `pin` would ever reach a manually-floated window).
    hl.window_rule({ match = { class = "^(helium)$", float = true },
      pin = true,
      size = { "monitor_w*0.28", "monitor_h*0.28" },
      move = { "monitor_w-window_w-16", "monitor_h-window_h-16" } })
    -- Chrome built-in notification → empty class AND empty title. Float (it tiles
    -- otherwise — a calendar alert wrecking the layout), pin, top-right. The empty
    -- title is what sets it apart from the video PiP above (also empty class).
    hl.window_rule({ match = { class = "^$", title = "^$" },
      float = true, pin = true,
      move = { "monitor_w-window_w-16", "16" } })
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
  # gate it on AC power — on AC the battery cost is moot and we want the dGPU
  # primary for gaming whether docked at the desk OR travelling on the internal
  # panel (games render on the dGPU and present to whatever panel is lit);
  # on battery leave AQ_DRM_DEVICES unset so the iGPU stays primary and the dGPU
  # powers down. The choice is made ONCE at session start — uwsm sources
  # env-${XDG_CURRENT_DESKTOP,,} (→ env-hyprland) as a POSIX shell script before
  # launching Hyprland — so applying a change needs a relog: powerTune's
  # battery→AC edge calls dock-relog (guarded 10s countdown), which snapshots the
  # windows and `uwsm stop`s; the new session then re-evaluates this on AC and
  # session-restore relaunches the windows. env-hyprland also records the chosen
  # mode in $XDG_RUNTIME_DIR/session-gpu-mode so dock-relog never relogs a session
  # that already booted dGPU-primary.
  #
  # GPUs are resolved through the stable by-path PCI symlinks (DRM card numbers
  # can reorder across boots) back to the canonical /dev/dri/cardN nodes that
  # aquamarine enumerates and matches against.
  xdg.configFile."uwsm/env-hyprland".text = ''
    # Resolve the two GPUs and classify the power source ONCE; every per-session
    # GPU/power decision below (primary render GPU, VA-API decode driver) keys off
    # these so they can't disagree. power-source (modules/nixos/mixins/asus.nix)
    # returns ac / powerbank / battery — a power bank is deliberately NOT `ac`, so
    # it gets the iGPU/battery path. Default to `ac` when it can't be read. The
    # whole file is re-evaluated on each (re)login, which is how a power change
    # takes effect — see the relog machinery in the let block.
    dgpu=$(readlink -f /dev/dri/by-path/pci-0000:02:00.0-card 2>/dev/null)
    igpu=$(readlink -f /dev/dri/by-path/pci-0000:00:02.0-card 2>/dev/null)
    ac=$(/run/current-system/sw/bin/power-source 2>/dev/null || echo ac)

    # Primary render/allocator GPU: dGPU on AC (zero-copy gaming), iGPU on battery
    # (so the dGPU can RTD3-sleep). Record the chosen mode for dock-relog's
    # "already dGPU?" guard.
    mode=igpu
    if [ "$ac" = ac ] && [ -n "$dgpu" ] && [ -n "$igpu" ]; then
      export AQ_DRM_DEVICES="$dgpu:$igpu"
      # Cross-GPU scanout survives suspend. With the dGPU primary, the internal
      # panel (eDP-1, on the iGPU) is fed by a cross-GPU copy: aquamarine renders
      # on the dGPU, exports a dmabuf and imports it into the iGPU's EGL context
      # to scan out. After an s2idle resume the dGPU re-exports that buffer with a
      # tiling modifier the iGPU can no longer import — eglCreateImageKHR fails
      # with EGL_BAD_MATCH, the eDP-1 page-flip never completes ("Cannot commit
      # when a page-flip is awaiting") and the panel stays black until reboot; a
      # relog or modeset doesn't clear it. Forcing a LINEAR intermediate buffer
      # for the multi-GPU blit makes that import modifier-independent, so it
      # survives resume. Only affects the eDP-1 copy — the game→dGPU→HDMI gaming
      # path is same-GPU (no blit), so zero gaming cost.
      export AQ_FORCE_LINEAR_BLIT=1
      mode=dgpu
    fi
    if [ -n "''${XDG_RUNTIME_DIR:-}" ]; then
      printf '%s\n' "$mode" > "$XDG_RUNTIME_DIR/session-gpu-mode" 2>/dev/null || true
    fi

    # VA-API hardware video decode GPU: nvidia on AC (decode on the dGPU), iHD
    # (Intel iGPU) on battery so the dGPU isn't woken by any app that plays video.
    # Replaces the old static LIBVA_DRIVER_NAME=nvidia in modules/nixos/mixins/
    # nvidia.nix; offloaded apps still force nvidia via pkgs.nvidiaOffloadEnv
    # regardless of this default.
    if [ "$ac" = ac ]; then
      export LIBVA_DRIVER_NAME=nvidia
    else
      export LIBVA_DRIVER_NAME=iHD
    fi
  '';

  # Power automation (see powerTune in the let block): refresh rate, power profile
  # and keyboard aura all follow AC/battery. Bound to graphical-session.target so it
  # starts and stops with the Hyprland session and inherits HYPRLAND_INSTANCE_SIGNATURE
  # (uwsm finalises it into the systemd user manager) — hyprctl needs it.
  systemd.user.services.power-tune = {
    Unit = {
      Description = "Refresh rate + keyboard aura + dGPU relog follow the power source";
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

  # — Qt platform theme + Quickshell icon theme —
  #
  # We now run a full Qt platform theme (qt6ct) so Qt apps follow Noctalia's
  # wallpaper-derived palette: Noctalia's builtin `qt` template (see noctalia.nix)
  # writes ~/.config/qt{5,6}ct/colors/noctalia.conf, and qt6ct.conf below points
  # at it with a Fusion style (Fusion honours the custom palette). Qt apps pick up
  # the colours at launch — no live recolour (Qt has no palette hot-reload).
  #
  # QT_QPA_PLATFORMTHEME=qt6ct also fixes the alttab switcher (alttab.nix, a
  # Quickshell/Qt6 app): Qt's icon theme now comes from qt6ct.conf (icon_theme =
  # Papirus-Dark) instead of falling back to the empty default (which rendered
  # every unresolved icon as the magenta/black "missing texture" placeholder).
  # QS_ICON_THEME is kept as a belt-and-braces Quickshell-specific override.
  #
  # Placed in uwsm/env (sourced for every uwsm session and imported into the
  # systemd user manager) so it reaches every Hyprland-spawned Qt app.
  xdg.configFile."uwsm/env".text = ''
    export QS_ICON_THEME="Papirus-Dark"
    export QT_QPA_PLATFORMTHEME="qt6ct"
  '';

  # The qt6ct/qt5ct.conf colour-scheme selection moved to
  # users/kyandesutter/mixins/qt.nix (the QT_QPA_PLATFORMTHEME env above stays
  # here so it reaches every uwsm/Hyprland-spawned Qt app).

  # Compositor-essential session packages. The generic GNOME/desktop apps and
  # their MIME defaults moved to users/kyandesutter/mixins/desktop-apps.nix.
  #   • wl-clip-persist: keeps the regular Wayland selection alive after the
  #     source app exits so noctalia's clipboard poller can capture it (launched
  #     from autostart.nix).
  #   • hyprpolkitagent: GUI polkit auth agent (started from hyprland.start).
  home.packages = with pkgs; [
    wl-clip-persist
    hyprpolkitagent

    # GTK theme noctalia's gtk template sets via gsettings/dconf (adw-gtk3-dark).
    # Installed here so that theme name resolves; noctalia, not the gtk module,
    # selects it (see the dark-mode block below).
    adw-gtk3

    # Qt platform theme engines. QT_QPA_PLATFORMTHEME=qt6ct (uwsm/env above) points
    # Qt6 apps at qt6ct; qt5ct themes Qt5 apps. Both read Noctalia's generated
    # colour scheme via the qt{6,5}ct.conf written in mixins/qt.nix.
    kdePackages.qt6ct
    libsForQt5.qt5ct
  ];

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
  # noctalia owns app theming now (see programs.noctalia.settings.theme.templates
  # in ../mixins/noctalia.nix). Its gtk3/gtk4 templates write the Catppuccin
  # palette to ~/.config/gtk-{3,4}.0/noctalia.css (imported via gtk.css) and their
  # apply.sh post-hook drives the *runtime* dark signal — `gsettings set
  # org.gnome.desktop.interface color-scheme prefer-dark` + `gtk-theme
  # adw-gtk3-dark` (also written to dconf). xdg-desktop-portal reports that to
  # native-Wayland libadwaita/GTK4 apps. So we no longer pin the theme *name*
  # here — noctalia chooses it (currently adw-gtk3-dark), and pinning our own
  # would drift if noctalia changes its choice.
  #
  # We keep this module for the two things noctalia does NOT do:
  #   • gtk.enable = true — the catppuccin module hooks on it to set the Papirus
  #     icon theme (gtk-icon-theme-name + dconf icon-theme).
  #   • gtk-application-prefer-dark-theme in settings.ini — the X11/XWayland
  #     fallback (no xsettingsd here). noctalia's apply.sh only touches gtk.css +
  #     gsettings/dconf, never settings.ini, so this remains our job.
  # adw-gtk3 stays installed (home.packages below) so noctalia's adw-gtk3-dark
  # resolves; gtk.css is left unmanaged here so noctalia owns it.
  gtk = {
    enable = true;
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

}
