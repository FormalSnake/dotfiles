{ pkgs, config, ... }:
let
  # Power-source-aware refresh rate + keyboard aura + dGPU dock-relog (see
  # systemd.user.services.power-tune).
  #
  # Subscribes to /run/power/state — published by the system reconciler in
  # modules/nixos/mixins/power.nix, the single authority on the power source
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
  #   - dGPU dock-relog: on any source change where the session's GPU mode no longer
  #     matches the source (→ac wants dGPU-primary; →power bank / →battery want iGPU-
  #     primary). dock-relog compares the session-gpu-mode marker against the source,
  #     self-guards (no-op when they already agree), gives a 15s cancel window and
  #     ends in `uwsm stop`. The AC→iGPU direction is what lets the system finally
  #     power the dGPU off — dgpu-power's wait-for-free loop (power.nix) rides out
  #     the session teardown before unloading.
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
          # Re-derive the per-session GPU env (AQ_DRM_DEVICES, the VA-API driver, the
          # EGL/Vulkan ICD pins) when the source no longer matches the session's GPU
          # mode. dGPU *power* is owned live by the system (power-reconcile →
          # dgpu-power, modules/nixos/mixins/power.nix: off on battery/power bank, on
          # for AC); this owns the session's *primary GPU*, which is frozen at login
          # because AQ_DRM_DEVICES is read once at aquamarine init — so switching it
          # needs a relog. dock-relog self-guards (instant no-op when the session is
          # already in the right mode, e.g. at startup or on a power bounce) and gives
          # a 15s cancel window. Backgrounded so this loop stays responsive; on a real
          # mode change it ends in `uwsm stop`, which tears the session down anyway.
          ${dockRelog}/bin/dock-relog &
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
  # on battery / power bank (so the dGPU can be powered off). powerTune's reconcile()
  # fires on every source change and calls dock-relog, which relogs in *either*
  # direction when the session's GPU mode no longer matches the source; env-hyprland
  # re-derives the GPU from the source on the new session; session-restore relaunches
  # the windows the last snapshot recorded. Restore also runs on *manual* relogs, so
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

  # Guarded relog, called by powerTune on any source change. Compares the session's
  # GPU mode (the session-gpu-mode marker written by env-hyprland) against the mode
  # the current source wants — dGPU-primary on AC, iGPU-primary on power bank /
  # battery — and relogs only when they disagree (so a session already in the right
  # mode, e.g. plugged in at boot or a source bounce, is a no-op). Shows a
  # notification with a 15s cancel window (Super+Shift+Backspace → `dock-relog
  # cancel` drops the cancel flag); if not canceled it takes a fresh snapshot and
  # `uwsm stop`s cleanly back to SDDM. On the next login env-hyprland re-derives the
  # GPU from the source and session-restore relaunches the windows. The →iGPU
  # direction also releases the dGPU so the system can finally power it off (see
  # dgpu-power's wait-for-free loop in power.nix).
  dockRelog = pkgs.writeShellApplication {
    name = "dock-relog";
    runtimeInputs = with pkgs; [ libnotify coreutils uwsm ];
    text = ''
      cancel="''${XDG_RUNTIME_DIR:-/tmp}/dock-relog.cancel"
      marker="''${XDG_RUNTIME_DIR:-/tmp}/session-gpu-mode"
      # Rate-limit stamp lives in the persistent state dir, NOT XDG_RUNTIME_DIR:
      # the runtime dir is torn down with the last session, which is exactly when
      # a relog loop would reset its own limiter.
      stamp="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-session/relog.last"

      if [ "''${1:-}" = cancel ]; then
        : > "$cancel"
        notify-send -t 1500 "GPU mode" "Auto-relog canceled." || true
        exit 0
      fi

      # Mode this session booted with (env-hyprland writes it); default iGPU.
      cur=igpu
      if [ -r "$marker" ]; then cur=$(cat "$marker"); fi

      # Mode the current source wants — mirrors env-hyprland's choice. Read the
      # published classifier (power-reconcile writes it); on anything unknown or
      # missing, don't relog (act only on a confident reading).
      want_for() {
        case "$1" in
          ac)                want=dgpu ;;
          powerbank|battery) want=igpu ;;
          *)                 want="$cur" ;;
        esac
      }
      src=""
      if [ -r /run/power/state ]; then src=$(cat /run/power/state); fi
      want_for "$src"

      # Already in the right mode → nothing to do.
      [ "$cur" = "$want" ] && exit 0

      # Anti-loop guard: if an auto-relog already fired < 2 minutes ago, don't
      # fire another. A session that crashes right back to SDDM (e.g. the dGPU
      # is wedged/unavailable while AC wants dGPU-primary) would otherwise
      # logout-loop forever — observed 2026-07-03 as back-to-back 2-second
      # sessions. The user can still relog manually; the next real power event
      # after the window retries automatically.
      now=$(date +%s)
      last=$(cat "$stamp" 2>/dev/null || echo 0)
      if [ $((now - last)) -lt 120 ]; then
        notify-send -t 5000 "GPU mode" "Auto-relog skipped (one ran <2 min ago). Log out manually to switch GPU mode." || true
        exit 0
      fi

      rm -f "$cancel"
      if [ "$want" = dgpu ]; then
        msg="On AC — relogging in 15s to make the dGPU primary."
      else
        msg="On battery — relogging in 15s to release the dGPU (iGPU primary)."
      fi
      notify-send -t 16000 "GPU mode" "$msg Super+Shift+Backspace to cancel." || true

      i=0
      while [ "$i" -lt 15 ]; do
        if [ -e "$cancel" ]; then rm -f "$cancel"; exit 0; fi
        sleep 1
        i=$((i + 1))
      done
      if [ -e "$cancel" ]; then rm -f "$cancel"; exit 0; fi

      # Re-check after the countdown: a source bounce back during the window can make
      # the relog unnecessary again.
      src=""
      if [ -r /run/power/state ]; then src=$(cat /run/power/state); fi
      want_for "$src"
      [ "$cur" = "$want" ] && exit 0

      mkdir -p "$(dirname "$stamp")"
      date +%s > "$stamp"
      ${sessionSnapshot}/bin/session-snapshot || true
      notify-send -t 2000 "GPU mode" "Relogging…" || true
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
    -- vrr = 0: adaptive sync OFF — the panel stays locked at a steady 144Hz.
    -- History: vrr = 1 (always-on) made the panel flicker on the desktop (its
    -- brightness tracks the variable refresh during scrolling/video/cursor), and
    -- vrr = 2 (fullscreen-only) cured that flicker but left games feeling laggy —
    -- the refresh rate visibly chases the framerate (e.g. dropping to ~100Hz) and
    -- the constant catch-up reads as judder/input lag. Locking to a fixed 144Hz
    -- trades the variable-refresh judder-smoothing for consistent presentation.
    hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@144", position = "0x0", scale = 1.0, vrr = 0 })
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

    -- Drop the window border on any workspace holding a single tiled window.
    -- `w[tv1]` is a dynamic selector = "workspace with exactly 1 tiled visible
    -- window"; on it we set no_border so a lone window sits flush with no frame.
    -- As soon as a second tiled window appears the selector stops matching and
    -- the global border_size (2) returns, giving the seams between tiled windows
    -- — and between a top window and the bar. This is a separate, state-based
    -- rule type from the per-number monitor bindings above, so the two coexist.
    hl.workspace_rule({ workspace = "w[tv1]", no_border = true })

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
      -- relogs restore too. The power-change relog itself is driven by powerTune
      -- (above), not here. pgrep-guarded like the alttab launcher so re-fires can't stack it.
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
        -- caps:escape — Caps Lock acts as Escape (no Caps Lock function).
        kb_options = "caps:escape",
        -- 2 = keyboard focus only changes on click (focus-follows-mouse off), but
        -- the hovered window still receives pointer events — so you can scroll an
        -- unfocused window under the cursor without it stealing keyboard focus.
        follow_mouse = 2,
        sensitivity = 0,
        -- clickfinger: a physical 2-finger press = RMB, 3-finger = MMB (replaces
        -- libinput's bottom-corner click areas). 2-finger tap already right-clicks
        -- via the default tap_to_click.
        -- scroll_factor < 1 dampens scroll velocity, taming the over-sensitive,
        -- long-coasting two-finger scroll.
        touchpad = { natural_scroll = true, clickfinger_behavior = true, scroll_factor = 0.4 },
      },
      general = {
        gaps_in = 0,
        gaps_out = 0,
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
        rounding = 0,
        blur = { enabled = false },
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
        -- FreeSync per-monitor via its `vrr = 2` (fullscreen-only) above, and the
        -- internal eDP-1 panel stays off. (The old judder we blamed on a
        -- 120fps-into-144Hz cadence mismatch turned out to be a GPU hybrid
        -- mismatch — now fixed —
        -- so adaptive sync is the right cure rather than the screen-tearing
        -- workaround.) allow_tearing / `immediate` / direct_scanout below remain
        -- available as a low-latency fullscreen path.
        vrr = 0,
      },
      render = {
        direct_scanout = 1,
        -- Auto-HDR: the desktop and both monitors stay SDR/8-bit at all times;
        -- when a fullscreen app requests an HDR swapchain (e.g. a game like
        -- Forza via Proton with PROTON_ENABLE_HDR=1), Hyprland flips that output
        -- to HDR for the duration and reverts on exit. 1 = generic BT.2020+PQ;
        -- bump to 2 (hdredid, uses the panel's EDID primaries) if HDR colours/
        -- brightness look off. If a game white-screens on launch, add
        -- `prefer_hdr = 1` here. HDR over HDMI-A-1 needs the dGPU primary, i.e.
        -- gaming on AC (see env-hyprland's AC GPU selection).
        cm_auto_hdr = 1,
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

    -- — Animations: snappy, short, with a decisive (non-mushy) landing —
    -- The default preset eases out with a long, near-zero-velocity tail over ~600–700ms,
    -- which reads as sluggish and slightly disorienting. `snappy` front-loads the motion
    -- (fast, responsive start) then lands with a real, non-flat end slope, so transitions
    -- "arrive" instead of crawling to a stop. Durations are in ds (1 ds = 100ms).
    -- Workspaces slide, so a switch visibly pushes in the direction you moved.
    hl.curve("snappy", { ["type"] = "bezier", ["points"] = { { 0.15, 0.75 }, { 0.35, 0.9 } } })

    hl.animation({ ["leaf"] = "windows",          ["enabled"] = true, ["bezier"] = "snappy", ["speed"] = 3 })
    hl.animation({ ["leaf"] = "windowsOut",       ["enabled"] = true, ["bezier"] = "snappy", ["speed"] = 3, ["style"] = "popin 90%" })
    hl.animation({ ["leaf"] = "layers",           ["enabled"] = true, ["bezier"] = "snappy", ["speed"] = 2.5 })
    hl.animation({ ["leaf"] = "fade",             ["enabled"] = true, ["bezier"] = "snappy", ["speed"] = 2.5 })
    hl.animation({ ["leaf"] = "border",           ["enabled"] = true, ["bezier"] = "snappy", ["speed"] = 5 })
    hl.animation({ ["leaf"] = "workspaces",       ["enabled"] = true, ["bezier"] = "snappy", ["speed"] = 3, ["style"] = "slide" })
    hl.animation({ ["leaf"] = "specialWorkspace", ["enabled"] = true, ["bezier"] = "snappy", ["speed"] = 3, ["style"] = "slidevert" })

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

    -- — Trackpad gestures (1:1 swipe) —
    -- 3-finger horizontal = workspace switch; 3-finger up = toggle fullscreen.
    hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
    hl.gesture({ fingers = 3, direction = "up", action = "fullscreen" })

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
    -- Sleep: lock then suspend on demand. noctalia's `session lock-and-suspend`
    -- locks the screen before suspending, so resume lands on the lock screen.
    hl.bind(mod .. " + SHIFT + Escape", hl.dsp.exec_cmd("noctalia msg session lock-and-suspend"))
    -- Cancel an in-progress GPU-mode auto-relog (the 15s countdown after a power
    -- source change). See dockRelog / powerTune in the let block.
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

    -- Volume / brightness / media all route through noctalia (msg IPC) so they
    -- share one OSD (bottom-center, see noctalia.nix) and stay in sync with the
    -- shell, rather than poking wpctl/playerctl/ddcutil directly:
    --   • volume / mic → speaker + mic, with the volume OSD.
    --   • brightness   → whichever monitor the CURSOR is on (`current`), in clean
    --     10% steps (a multiple of 5 → stays on a tidy grid, no read-snap needed).
    --     The external monitor is driven over DDC/CI because noctalia.nix sets
    --     [brightness] enable_ddcutil = true; the internal panel uses the backlight
    --     backend. Same code path as noctalia's brightness slider.
    --   • media        → the ACTIVE MPRIS player noctalia tracks (the one shown in
    --     its media widget), so the keys follow Spotify, not a background YouTube
    --     tab — `playerctl` picked the wrong player by default.
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("noctalia msg volume-up"), { repeating = true })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("noctalia msg volume-down"), { repeating = true })
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd("noctalia msg volume-mute"))
    hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("noctalia msg mic-mute"))
    hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("noctalia msg brightness-up current 10"), { repeating = true })
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("noctalia msg brightness-down current 10"), { repeating = true })

    -- Media playback (G815 dedicated keys) via noctalia → the active MPRIS player.
    hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("noctalia msg media toggle"))
    hl.bind("XF86AudioPause", hl.dsp.exec_cmd("noctalia msg media toggle"))
    hl.bind("XF86AudioNext", hl.dsp.exec_cmd("noctalia msg media next"))
    hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("noctalia msg media previous"))
    hl.bind("XF86AudioStop", hl.dsp.exec_cmd("noctalia msg media stop"))

    -- Mouse drag/resize (aerospace SUPER+LMB move, SUPER+RMB resize).
    hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
    hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

    -- — Window → workspace rules (ported from the aerospace setup; Linux app
    --   classes. Verify exact classes on hardware with `hyprctl clients`). —
    -- No `silent`: when one of these apps opens, Hyprland follows the window to
    -- its assigned workspace (add "silent" back to a rule to keep it in the
    -- background instead).
    hl.window_rule({ match = { class = "^([Hh]elium)$" }, workspace = "1" })                       -- web
    -- Terminal (ghostty) intentionally has no workspace rule: it opens on the
    -- active workspace instead of always landing on ws2.
    hl.window_rule({ match = { class = "^([Cc]ode|[Zz]ed|dev.zed.Zed)$" }, workspace = "3" })      -- development
    hl.window_rule({ match = { class = "^([Ss]lack|WhatsApp|[Ee]quibop|discord|[Bb]eeper|[Bb]lue[Bb]ubbles)$" }, workspace = "4" })  -- communication (incl. Discord/equibop/Beeper/BlueBubbles, internal panel)
    -- Beeper (Electron) maps its main window as floating, so it never tiles. Force
    -- it back into the dwindle layout; it still lands on ws4 via the rule above.
    hl.window_rule({ match = { class = "^([Bb]eeper)$" }, float = false })                            -- beeper → tiled
    hl.window_rule({ match = { class = "^([Bb]lue[Bb]ubbles)$" }, float = false })                    -- bluebubbles → tiled
    hl.window_rule({ match = { class = "^([Cc]laude)$" }, workspace = "7" })                       -- ai
    hl.window_rule({ match = { class = "^([Ss]potify)$" }, workspace = "8" })                      -- media
    hl.window_rule({ match = { class = "^([Ss]team|steam)$" }, workspace = "9" })                 -- gaming
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
    -- GNOME spacebar quick-preview (Sushi / NautilusPreviewer): float + center it
    -- so it pops up like macOS Quick Look instead of tiling into the layout. It
    -- sizes itself to the previewed content, so no size rule — just float+center.
    hl.window_rule({ match = { class = "^(org.gnome.NautilusPreviewer)$" },
      float = true, center = true })
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
  # launching Hyprland — so applying a change needs a relog: powerTune's reconcile()
  # calls dock-relog on every source change (guarded 15s countdown), which snapshots
  # the windows and `uwsm stop`s in either direction when the session's GPU mode no
  # longer matches the source; the new session then re-evaluates this and
  # session-restore relaunches the windows. env-hyprland records the chosen mode in
  # $XDG_RUNTIME_DIR/session-gpu-mode, which dock-relog compares against the source
  # so it only relogs when they actually disagree.
  #
  # GPUs are resolved through the stable by-path PCI symlinks (DRM card numbers
  # can reorder across boots) back to the canonical /dev/dri/cardN nodes that
  # aquamarine enumerates and matches against.
  xdg.configFile."uwsm/env-hyprland".text = ''
    # Resolve the two GPUs and classify the power source ONCE; every per-session
    # GPU/power decision below (primary render GPU, VA-API decode driver) keys off
    # these so they can't disagree. power-source (modules/nixos/mixins/power.nix)
    # returns ac / powerbank / battery — a power bank is deliberately NOT `ac`, so
    # it gets the iGPU/battery path. Default to `ac` when it can't be read. The
    # whole file is re-evaluated on each (re)login, which is how a power change
    # takes effect — see the relog machinery in the let block.
    dgpu=$(readlink -f /dev/dri/by-path/pci-0000:02:00.0-card 2>/dev/null)
    igpu=$(readlink -f /dev/dri/by-path/pci-0000:00:02.0-card 2>/dev/null)
    ac=$(/run/current-system/sw/bin/power-source 2>/dev/null || echo ac)

    # Primary render/allocator GPU: dGPU on AC (zero-copy gaming), iGPU on battery
    # (so the dGPU can be powered off). Record the chosen mode so dock-relog can tell
    # whether this session already matches the current source.
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
    elif [ -n "$igpu" ]; then
      # Battery: pin the compositor to the iGPU *only* — name just that one card so
      # aquamarine never enumerates the dGPU. Leaving AQ_DRM_DEVICES unset is NOT
      # enough: aquamarine then probes every card, and since the dGPU is card0 it
      # gets opened anyway (Xwayland grabs /dev/dri/card0, and that single open
      # handle pins the dGPU at D0 — RTD3 never arms and it never sleeps). With only
      # the iGPU named, the dGPU's DRM node is never touched by the session, so it
      # can RTD3-sleep. Offloaded apps (pkgs.nvidiaOffloadEnv) still open the dGPU
      # directly on demand and present back through the iGPU.
      export AQ_DRM_DEVICES="$igpu"
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
      # Keep Chromium/Electron (and any other GL/Vulkan client) off the dGPU on
      # battery. Pinning the compositor to the iGPU above is not enough: these apps
      # run their own GPU process that enumerates EGL/Vulkan vendors independently
      # and will open the nvidia render node (/dev/dri/renderD12x) — another handle
      # that pins the dGPU at D0. Exposing only the iGPU's Mesa EGL + Intel Vulkan
      # ICD makes them open the iGPU node instead, so the dGPU stays asleep.
      # Offloaded apps re-expand the vendor list themselves (they set their own
      # __GLX/__VK env), and on AC nothing is restricted so gaming is untouched.
      export __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json
      export VK_DRIVER_FILES=/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json
      export VK_ICD_FILENAMES="$VK_DRIVER_FILES"
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
  # Colloid-Dark) instead of falling back to the empty default (which rendered
  # every unresolved icon as the magenta/black "missing texture" placeholder).
  # QS_ICON_THEME is kept as a belt-and-braces Quickshell-specific override.
  #
  # Placed in uwsm/env (sourced for every uwsm session and imported into the
  # systemd user manager) so it reaches every Hyprland-spawned Qt app.
  xdg.configFile."uwsm/env".text = ''
    export QS_ICON_THEME="Colloid-Dark"
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

    # Icon themes. Colloid-Dark is the desktop-wide icon set (set via gtk.iconTheme
    # below, plus qt{5,6}ct.conf + QS_ICON_THEME above for Qt/Quickshell). adwaita
    # is kept as the complete freedesktop fallback so any icon Colloid lacks
    # resolves to a real glyph instead of the broken-image placeholder.
    colloid-icon-theme
    adwaita-icon-theme

    # Qt platform theme engines. QT_QPA_PLATFORMTHEME=qt6ct (uwsm/env above) points
    # Qt6 apps at qt6ct; qt5ct themes Qt5 apps. Both read Noctalia's generated
    # colour scheme via the qt{6,5}ct.conf written in mixins/qt.nix.
    kdePackages.qt6ct
    libsForQt5.qt5ct
  ];

  # Cursor theme — Bibata Modern Classic, the black variant
  # (https://www.opendesktop.org/p/1197198/). Sets it for GTK, native Wayland
  # (hyprcursor) and X11/XWayland (x11.enable exports XCURSOR_THEME/SIZE) so every
  # app shows the same cursor.
  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
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
  # We keep this module for the things noctalia does NOT do:
  #   • gtk.iconTheme — sets Colloid-Dark as the icon theme (gtk-icon-theme-name in
  #     settings.ini + org.gnome.desktop.interface icon-theme in dconf). Noctalia
  #     never touches the icon theme, so without this GTK falls back to hicolor and
  #     renders every app/mime icon as the broken-image placeholder. (This used to
  #     be the catppuccin module's job, but autoEnable = false disabled that hook.)
  #   • gtk-application-prefer-dark-theme in settings.ini — the X11/XWayland
  #     fallback (no xsettingsd here). noctalia's apply.sh only touches gtk.css +
  #     gsettings/dconf, never settings.ini, so this remains our job.
  # adw-gtk3 stays installed (home.packages below) so noctalia's adw-gtk3-dark
  # resolves; gtk.css is left unmanaged here so noctalia owns it. We set the icon
  # theme but NOT theme.name — leaving gtk-theme unpinned so noctalia owns it.
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
