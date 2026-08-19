{ pkgs, config, lib, osConfig ? { }, ... }:
let
  flexoki = import ./flexoki/palette.nix;

  dmsBin = "${config.programs.dank-material-shell.package}/bin/dms";

  # Shell selector from the host (kyan.desktop.shell, default "dms") picks
  # which shell the shell-facing binds below spawn into. Both package
  # references stay lazy: only the active arm's option is ever forced, so the
  # inactive shell's package option can be unset without breaking eval.
  useFormalshell = (((osConfig.kyan or { }).desktop or { }).shell or "dms") == "formalshell";
  fsBin = "${config.programs.formalshell.package}/bin/formalshell";
  fsIpc = args: "${fsBin} ipc --any-display call " + lib.concatStringsSep " " args;

  # NVIDIA dGPU flag from the host (same gate as dms.nix/godot.nix). Everything
  # below that exists for the g815's dGPU power model — power-tune,
  # gpu-relog-prompt, the AQ_DRM_DEVICES pick, the two-monitor layout — is
  # gated on it, so iGPU-only hosts (e1504g) get a plain Hyprland session with
  # none of the machinery (and none of its hardcoded g815 PCI paths / modes).
  hasNvidia = (osConfig.kyan or { }).nvidia.enable or false;

  # Workspace pill labels: role → Nerd Font glyph + short name, mirroring the
  # macOS aerospace workspace names (see mixins/aerospace.nix). Rendered into
  # each workspace's `default_name`, which is what Hyprland reports over IPC as
  # `name` and what FormalShell's HyprlandBackend puts on the bar pills
  # (shell/Compositor/hyprland/HyprlandBackend.qml maps `w.name` straight
  # through).
  # Glyph and name are joined by an EM SPACE ( ), not an ASCII space —
  # the bar widget collapses ASCII/nbsp whitespace in the label but preserves
  # it. Written as JSON \u escapes so the private-use glyphs survive editing;
  # glyphs verified present in GeistMono Nerd Font 3.4.0.
  wsName = builtins.fromJSON ''
    {"1": " web", "2": " term", "3": " dev", "4": " chat", "5": " prod", "6": " print", "7": "󰚩 ai", "8": " media", "9": " game"}
  '';
  wsLua = lib.concatMapStringsSep ", " (i: ''"${wsName.${toString i}}"'') (lib.range 1 9);

  # Power-source-aware refresh rate + keyboard aura + relog consent prompt (see
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
  #     dms.nix), passing the cached wallpaper accent. ac=static,
  #     powerbank=breathe ("charging" vibe), battery=dark.
  #   - refresh rate: eDP-1 is 2560x1600@240Hz; drop to 60Hz whenever the active
  #     PPD profile is power-saver, restore 240Hz otherwise. Refresh follows the
  #     *profile* (not the source) so a manual power-saver toggle in the shell
  #     also drops to 60Hz. Applied live through `hyprctl eval` — Hyprland has
  #     real runtime monitor control, so unlike the niri era there is no config
  #     fragment to rewrite and no reload to trigger.
  #   - relog consent prompt: every event re-runs gpu-relog-prompt (below),
  #     which decides whether a GPU-topology relog is worth OFFERING (persistent
  #     notification, user confirms or dismisses — NEVER automatic).
  #   - dGPU convergence kick: once at startup, `systemctl start
  #     dgpu-reconcile.service` (polkit rule in power.nix) so a fresh login
  #     finally powers off a dGPU a previous session was holding.
  #
  # Event-driven, no polling: three monitors feed one loop through a single
  # process substitution (which keeps the loop in this shell so last_src/
  # last_rate persist) — inotifywait on /run/power/state for source changes,
  # dbus-monitor on PPD for profile changes (the refresh follow), and udevadm
  # on the drm subsystem for monitor/GPU hotplug. The inner `wait` keeps the
  # substitution alive while the backgrounded monitors run.
  powerTune = pkgs.writeShellApplication {
    name = "power-tune";
    runtimeInputs = with pkgs; [
      hyprland # hyprctl
      power-profiles-daemon # powerprofilesctl
      inotify-tools # inotifywait
      dbus # dbus-monitor
      jq # set_refresh reads the live rate from `hyprctl monitors -j`
      coreutils
    ];
    text = ''
      source_now() { cat /run/power/state 2>/dev/null || echo battery; }

      profile() {
        powerprofilesctl get 2>/dev/null
      }

      # `hyprctl eval` takes a Lua string and runs it against the live config
      # context, so the monitor keyword applies immediately and survives until
      # the next `hyprctl reload` (which re-reads hyprland.lua's own 240Hz
      # line). Hyprland matches the requested refresh to the closest real mode.
      # Compared against the compositor's live rate, not a cached one: a
      # `hyprctl reload` mid-power-saver restores 240Hz behind our back, and a
      # stale cache would leave it there until the next profile flip.
      set_refresh() {
        cur="$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.name == "eDP-1") | .refreshRate | round' 2>/dev/null || true)"
        if [ "$cur" = "$1" ]; then return 0; fi
        hyprctl eval \
          "hl.monitor({ output = \"eDP-1\", mode = \"2560x1600@$1\", position = \"2560x0\", scale = 1.25 })" \
          >/dev/null 2>&1 || true
      }

      reconcile() {
        src="$(source_now)"
        if [ "$src" != "$last_src" ]; then
          # Repaint the keyboard for the new source via the shared setter (in the
          # home profile — user services have a limited PATH, so reference it
          # absolutely), using the cached wallpaper accent (fall back to the seed).
          colour="$(cat "$HOME/.cache/dank/aura-color" 2>/dev/null || echo b15bf5)"
          ${config.home.profileDirectory}/bin/aura-repaint "$colour" || true
          last_src="$src"
        fi
        case "$(profile)" in
          power-saver) set_refresh 60 ;;
          *)           set_refresh 240 ;;
        esac
        # Consent popup (self-guarding: single instance, remembers dismissals,
        # no-ops when the session already fits the situation). Backgrounded so
        # this loop stays responsive; on a confirmed relog it ends in
        # `uwsm stop`, which tears this unit down with the session.
        ${gpuRelogPrompt}/bin/gpu-relog-prompt &
      }

      # Converge dGPU power for THIS login: a popup-confirmed relog happens
      # long after the battery event that wanted the dGPU off, so the fresh
      # session kicks the (start-only, serialized) system reconciler once.
      # Passwordless via a polkit rule scoped to exactly this unit+verb
      # (modules/nixos/mixins/power.nix).
      /run/current-system/sw/bin/systemctl start dgpu-reconcile.service 2>/dev/null || true

      last_src=""
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
        # GPU/monitor hotplug (drm "change" uevents). udevadm via the system
        # profile — user services have a limited PATH.
        /run/current-system/sw/bin/udevadm monitor --udev --subsystem-match=drm 2>/dev/null &
        wait
      } )
    '';
  };

  # Consent relog prompt — the ONLY path to a GPU-topology relog.
  #
  # aquamarine freezes the session's GPU set at init from AQ_DRM_DEVICES (see
  # uwsm/env-hyprland below), so changing it needs a full session restart.
  # Exactly two situations qualify:
  #   monitor — a monitor is connected on the powered dGPU but this session
  #             booted without the dGPU (marker `igpu`), so it can't light it
  #             up. (If aquamarine hot-adds the card by itself, hyprctl shows
  #             the output and this never fires — self-adapting.)
  #   battery — on battery with no external monitor, but the session still
  #             holds the dGPU (marker `igpu+dgpu`), so it can't power off.
  # No countdown, no default action: a persistent notification with [Relog now]/
  # [Not now] buttons (both shells' notification daemons support actions via
  # notify-send -A; Super+Shift+BackSpace is a belt-and-braces confirm for a
  # daemon that doesn't). A dismissal is remembered per-situation and never
  # re-prompted until the situation clears (the `dismissed` file is dropped
  # whenever evaluate() says `none`). Confirming re-checks the situation and
  # `uwsm stop`s; autostart.nix's login services come back with the new session.
  gpuRelogPrompt = pkgs.writeShellApplication {
    name = "gpu-relog-prompt";
    runtimeInputs = with pkgs; [ libnotify coreutils util-linux jq uwsm hyprland ];
    text = ''
      rt="''${XDG_RUNTIME_DIR:-/tmp}"
      confirm="$rt/gpu-relog.confirm"
      dismissed="$rt/gpu-relog.dismissed"
      outfile="$rt/gpu-relog.action"
      marker="$rt/session-gpu-mode"

      # Keybind fallback: Super+Shift+BackSpace drops the confirm flag.
      if [ "''${1:-}" = confirm ]; then : > "$confirm"; exit 0; fi

      # Which relog (if any) does the current situation want?
      evaluate() {
        cur=igpu
        [ -r "$marker" ] && cur=$(cat "$marker")
        # Default `unknown`, NOT `battery`: at login this runs before
        # power-reconcile has written /run/power/state (a ~2s window), so a
        # `battery` default would fire a spurious relog offer on a charger
        # boot. Only positively-confirmed battery reaches the prompt below.
        src=unknown
        [ -r /run/power/state ] && src=$(cat /run/power/state)
        card="$(readlink -f /dev/dri/by-path/pci-0000:02:00.0-card 2>/dev/null || true)"
        kern_conn=
        if [ -n "$card" ]; then
          for s in "/sys/class/drm/''${card##*/}"-*/status; do
            [ -e "$s" ] || continue
            if [ "$(cat "$s" 2>/dev/null)" = connected ]; then kern_conn=1; break; fi
          done
        fi
        # Does the session already drive any external output?
        sess_ext=
        if hyprctl monitors -j 2>/dev/null | jq -e 'map(select(.name != "eDP-1")) | length > 0' >/dev/null 2>&1; then
          sess_ext=1
        fi
        if [ "$cur" = igpu ] && [ -n "$kern_conn" ] && [ -z "$sess_ext" ]; then
          echo monitor
        elif [ "$cur" = "igpu+dgpu" ] && [ "$src" = battery ] && [ -z "$kern_conn" ]; then
          echo battery
        else
          echo none
        fi
      }

      need=$(evaluate)
      if [ "$need" = none ]; then
        rm -f "$dismissed"
        exit 0
      fi
      # Already dismissed for THIS situation (reason-keyed, so dismissing the
      # dock offer doesn't also silence a later battery offer) → stay quiet.
      [ -e "$dismissed" ] && [ "$(cat "$dismissed" 2>/dev/null)" = "$need" ] && exit 0

      # One prompt at a time.
      exec 9>"$rt/gpu-relog.lock"
      flock -n 9 || exit 0

      rm -f "$confirm" "$outfile"
      case "$need" in
        monitor)
          title="External monitor detected"
          body="This session can't drive the dGPU's outputs. Relog to enable the monitor? (Super+Shift+BackSpace also confirms)" ;;
        *)
          title="On battery"
          body="This session holds the dGPU (~10W). Relog to power it off? (Super+Shift+BackSpace also confirms)" ;;
      esac

      notify-send -t 0 -u critical \
        -A relog="Relog now" -A dismiss="Not now" \
        "$title" "$body" \
        > "$outfile" 2>/dev/null &
      np=$!

      act=dismiss
      while :; do
        if [ -e "$confirm" ]; then act=relog; break; fi
        if ! kill -0 "$np" 2>/dev/null; then
          # Button clicked (stdout has the action) or notification closed.
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
        *) printf '%s' "$need" > "$dismissed"; exit 0 ;;
      esac

      # Re-check right before acting — the situation may have evaporated
      # between click and here.
      [ "$(evaluate)" = "$need" ] || exit 0
      notify-send -t 2000 "GPU mode" "Relogging…" || true
      uwsm stop
    '';
  };

  # Focused-output-aware brightness keys (dms arm only; the formalshell arm
  # drives brightnessctl + an OSD call directly).
  #
  # DMS's own `brightness increment/decrement` with an empty device selector
  # resolves to its "preferred device", and its default picks the internal
  # backlight whenever the internal panel is active AT ALL — not whichever
  # output is currently focused. On a docked laptop that means the brightness
  # keys always hit the internal panel, even while focused on the desk monitor.
  # So this script picks the device itself, keyed off Hyprland's *focused*
  # monitor: internal-panel regex match (or hyprctl unreachable) → empty
  # selector (DMS's own internal-panel default), otherwise the first `ddc:`
  # device from `brightness list`.
  #
  # DDC ids are discovered fresh on every keypress rather than hardcoded or
  # pinned once: they're `ddc:i2c-<N>`, and the i2c bus number a monitor lands
  # on shifts across boots/replugs (udev enumeration order, not a stable
  # identity).
  brightnessKey = pkgs.writeShellApplication {
    name = "brightness-key";
    # dms on PATH rather than interpolating dmsBin directly: the dms-shell
    # store path embeds a literal "=" (its +date=... version suffix), which
    # shellcheck's parser misreads as a `word=value` assignment prefix
    # (SC2276) when that path is the leading token of a command.
    runtimeInputs = [
      config.programs.dank-material-shell.package # dms
      pkgs.hyprland # hyprctl
      pkgs.jq
      pkgs.gnugrep
      pkgs.coreutils
    ];
    text = ''
      dir="''${1:?usage: brightness-key up|down}"
      case "$dir" in
        up) verb=increment ;;
        down) verb=decrement ;;
        *) echo "usage: brightness-key up|down" >&2; exit 1 ;;
      esac

      focused="$(hyprctl monitors -j 2>/dev/null | jq -r 'first(.[] | select(.focused)) | .name // empty')"
      device=""
      if [ -n "$focused" ] && ! printf '%s' "$focused" | grep -qiE '^(eDP|LVDS|DSI)'; then
        device="$(dms ipc call brightness list 2>/dev/null | grep -oE 'ddc:[^[:space:]]+' | head -n1 || true)"
      fi
      dms ipc call brightness "$verb" 5 "$device"
    '';
  };

  # — Monitors —
  #
  # g815: the desk monitor (ASUS PA278CGV, 1440p144) is wired to the dGPU. Its
  # EDID-preferred timing is 60Hz, so the 144Hz mode is pinned explicitly.
  # Placed at the ORIGIN (0x0) so it is the *primary* display — fullscreen games
  # with no monitor selector target the monitor at (0,0) and enumerate only its
  # modes. vrr = 0: adaptive sync OFF, the panel stays locked at a steady 144Hz
  # (vrr = 1 flickered on the desktop, vrr = 2 left games chasing the framerate
  # — and gaming lives on Windows now). The internal 18" WQXGA 240Hz panel sits
  # to its RIGHT at x = 2560, scale 1.25; power-tune flips its refresh at
  # runtime via `hyprctl eval`.
  #
  # Everywhere else: the internal panel at its preferred mode, native 1x (the
  # e1504g's 15.6" 1080p panel would otherwise land on a fractional scale).
  monitors =
    if hasNvidia then ''
      hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@144", position = "0x0", scale = 1.0, vrr = 0 })
      hl.monitor({ output = "eDP-1", mode = "2560x1600@240", position = "2560x0", scale = 1.25 })
    '' else ''
      hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.0 })
    '';

  # Workspace → monitor binding. On the two-monitor g815, communication (4) and
  # media (8) live on the internal panel and the other seven on the desk
  # monitor; each monitor gets one `default` workspace shown when it comes up
  # (1 on HDMI-A-1, 4 on eDP-1). When HDMI-A-1 is absent Hyprland relocates its
  # workspaces to eDP-1 and moves them back on reconnect. Single-panel hosts
  # take the names and nothing else.
  workspaceRules =
    if hasNvidia then ''
      local internalWorkspaces = { [4] = true, [8] = true }
      for i = 1, 9 do
        hl.workspace_rule({
          workspace = tostring(i),
          default_name = wsName[i],
          monitor = internalWorkspaces[i] and "eDP-1" or "HDMI-A-1",
          default = (i == 1 or i == 4),
        })
      end
    '' else ''
      for i = 1, 9 do
        hl.workspace_rule({ workspace = tostring(i), default_name = wsName[i] })
      end
    '';

  # Shell-facing binds (launcher, clipboard, theme, lock, screenshots,
  # media/volume/brightness keys) in a per-shell arm picked by
  # kyan.desktop.shell; everything compositor-native is shared below.
  #
  # `locked = true` is Hyprland's allow-when-locked: volume and brightness keep
  # working on the lock screen. `repeating = true` is held-key repeat (the old
  # `bindel`).
  shellBinds =
    if useFormalshell then ''
      -- FormalShell IPC. `menu toggle` is the no-argument verb M13 added for
      -- exactly this bind: root summon when closed, close when already open.
      hl.bind(mod .. " + Space", hl.dsp.exec_cmd("${fsIpc [ "menu" "toggle" ]}"))
      -- Emoji picker (M12): the menu's emoji route, same muscle memory as
      -- DMS's spotlight :e trigger. Enter copies the pick, the clipboard
      -- service captures it.
      hl.bind(mod .. " + period", hl.dsp.exec_cmd("${fsIpc [ "menu" "summon" "emoji" ]}"))
      -- ñ is a dedicated key on the es layout; its XKB keysym is `ntilde`.
      hl.bind(mod .. " + ntilde", hl.dsp.exec_cmd("${fsIpc [ "menu" "summon" "clipboard" ]}"))
      -- Quake console (FormalShell M37): one ghostty that drops over whatever
      -- workspace you are on and parks on Hyprland's special:formalshell-console
      -- when toggled off, session intact. The shell spawns it from
      -- console.command; nothing here needs a window rule, since it places the
      -- window itself on every show. `+` is unshifted on the es layout.
      hl.bind(mod .. " + plus", hl.dsp.exec_cmd("${fsIpc [ "console" "toggle" ]}"))
      hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd("${fsBin} theme mode toggle"))
      -- Sleep: lock then suspend on demand, so resume lands on the lock screen
      -- (the shell has no combined verb, and exec_cmd runs through sh -c).
      hl.bind(mod .. " + SHIFT + Escape", hl.dsp.exec_cmd("${fsIpc [ "lock" "lock" ]} && systemctl suspend"))

      -- Screenshots via the shell (M12 screenshot IPC target: grim/slurp on the
      -- wrapper PATH, saves to screenshot.directory and wl-copy's the image,
      -- success lands as a shell notification). Owner rule: when the shell has
      -- the feature, prefer it over the compositor's built-in — it's WM-agnostic,
      -- so the binds survive compositor changes. Print = whole screen,
      -- Mod+Shift+S = the capture picker (macOS Cmd+Shift+5): a toolbar of
      -- three shot and three record modes, digits 1-6 to switch between them,
      -- Tab and the arrows to cycle windows, Return to commit. `screenshot
      -- region` is the older bare-slurp route with no toolbar and no
      -- recording at all, so it is deliberately not bound here.
      hl.bind("Print", hl.dsp.exec_cmd("${fsIpc [ "screenshot" "full" ]}"))
      hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("${fsIpc [ "screenshot" "pick" "smart" "default" ]}"))

      -- Volume via wpctl: FormalShell's AudioService tracks PipeWire directly
      -- and auto-shows the volume OSD on any external change, so the keys don't
      -- need to route through the shell. Brightness has no such watcher; the
      -- documented pattern is brightnessctl plus an explicit OSD show. Media
      -- routes through the shell's active MPRIS player.
      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("${pkgs.wireplumber}/bin/wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 3%+"), { locked = true, repeating = true })
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%-"), { locked = true, repeating = true })
      hl.bind("XF86AudioMute", hl.dsp.exec_cmd("${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
      hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
      hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("${pkgs.brightnessctl}/bin/brightnessctl set 5%+ && ${fsIpc [ "osd" "brightness" ]}"), { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("${pkgs.brightnessctl}/bin/brightnessctl set 5%- && ${fsIpc [ "osd" "brightness" ]}"), { locked = true, repeating = true })
      hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("${fsIpc [ "media" "playPause" ]}"))
      hl.bind("XF86AudioPause", hl.dsp.exec_cmd("${fsIpc [ "media" "playPause" ]}"))
      hl.bind("XF86AudioNext", hl.dsp.exec_cmd("${fsIpc [ "media" "next" ]}"))
      hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("${fsIpc [ "media" "previous" ]}"))
    '' else ''
      -- App launcher / clipboard / theme / lock via DMS IPC.
      hl.bind(mod .. " + Space", hl.dsp.exec_cmd("${dmsBin} ipc call spotlight toggle"))
      -- Emoji picker: the emojiLauncher plugin (enabled in mixins/dms.nix) adds
      -- an emoji/unicode surface to DMS's spotlight under its `:e` trigger;
      -- toggleQuery opens the launcher pre-filled with it.
      hl.bind(mod .. " + period", hl.dsp.exec_cmd("${dmsBin} ipc call spotlight toggleQuery :e"))
      -- ñ is a dedicated key on the es layout; its XKB keysym is `ntilde`.
      hl.bind(mod .. " + ntilde", hl.dsp.exec_cmd("${dmsBin} ipc call clipboard toggle"))
      hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd("${dmsBin} ipc call theme toggle"))
      -- Sleep: lock then suspend on demand, so resume lands on the lock screen.
      -- DMS's lock IPC only locks (no combined lock+suspend verb).
      hl.bind(mod .. " + SHIFT + Escape", hl.dsp.exec_cmd("${dmsBin} ipc call lock lock && systemctl suspend"))

      -- Screenshots via DMS (owner rule: the shell owns it, so the binds
      -- survive compositor changes). `dms screenshot` is a top-level
      -- subcommand, not `ipc call`. Print = whole screen; Mod+Shift+S = region
      -- picker (macOS Cmd+Shift+4 — bare `dms screenshot` defaults to region).
      hl.bind("Print", hl.dsp.exec_cmd("${dmsBin} screenshot full"))
      hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("${dmsBin} screenshot"))

      -- Volume / brightness / media all route through DMS so they share one OSD
      -- and stay in sync with the shell. Brightness goes via brightness-key (see
      -- the let block), which resolves the device from Hyprland's focused
      -- monitor instead of DMS's internal-panel-first default.
      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("${dmsBin} ipc call audio increment 3"), { locked = true, repeating = true })
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("${dmsBin} ipc call audio decrement 3"), { locked = true, repeating = true })
      hl.bind("XF86AudioMute", hl.dsp.exec_cmd("${dmsBin} ipc call audio mute"))
      hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("${dmsBin} ipc call audio micmute"))
      hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("${brightnessKey}/bin/brightness-key up"), { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("${brightnessKey}/bin/brightness-key down"), { locked = true, repeating = true })
      hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("${dmsBin} ipc call mpris playPause"))
      hl.bind("XF86AudioPause", hl.dsp.exec_cmd("${dmsBin} ipc call mpris playPause"))
      hl.bind("XF86AudioNext", hl.dsp.exec_cmd("${dmsBin} ipc call mpris next"))
      hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("${dmsBin} ipc call mpris previous"))
      hl.bind("XF86AudioStop", hl.dsp.exec_cmd("${dmsBin} ipc call mpris stop"))
    '';
in
{
  # Hyprland is enabled at the system level (programs.hyprland in
  # modules/nixos/mixins/hyprland.nix); this module owns the user config.
  #
  # Hyprland 0.55 replaced the hyprlang `.conf` config with Lua at
  # ~/.config/hypr/hyprland.lua (the old syntax was removed, not deprecated).
  # home-manager's `wayland.windowManager.hyprland.settings` still serialises
  # hyprlang ($mod = SUPER, bind = …), which the Lua parser rejects
  # ("<name> expected near '$'"), so we write the file ourselves and skip the
  # HM module rather than have it emit a conflicting one.
  #
  # Nix `''` strings are safe here because the Lua contains no literal `${…}`
  # — every `${…}` below is a deliberate Nix interpolation of a store path.
  # API reference: https://wiki.hypr.land/Configuring/ (hl.config, hl.monitor,
  # hl.env, hl.bind, hl.dsp.*, hl.window_rule, hl.workspace_rule, hl.gesture).
  xdg.configFile."hypr/hyprland.lua".text = ''
    -- — Monitors —
    ${monitors}
    -- Catch-all: any other external display at its highest refresh rate
    -- ("highrr" forces the panel's max, unlike "preferred" which is usually
    -- 60Hz), placed to the right of whatever precedes it.
    hl.monitor({ output = "", mode = "highrr", position = "auto", scale = 1.0 })

    -- — Variables —
    local mod = "SUPER"        -- primary modifier (the physical Cmd-position key)
    local terminal = "ghostty"

    -- — Workspaces —
    -- Nine named workspaces mirroring the macOS/aerospace assignment. The name
    -- is what the bar renders on each pill; binds and window rules address the
    -- numeric id.
    local wsName = { ${wsLua} }

    ${workspaceRules}

    -- — Environment —
    -- Cursor theme/size for XWayland (X11) clients — without XCURSOR_THEME they
    -- fall back to a default theme and show a *different* cursor than native
    -- Wayland apps (which read it from home.pointerCursor below).
    hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
    hl.env("XCURSOR_SIZE", "24")
    -- Qt platform theme (qt6ct) so Qt apps follow the shell's palette (see the
    -- qt6ct notes in mixins/qt.nix); QS_ICON_THEME is the Quickshell-specific
    -- icon override kept for Qt tooling. Also exported from uwsm/env below, so
    -- systemd user services (which do NOT inherit Hyprland's environment) get
    -- them too.
    hl.env("QS_ICON_THEME", "Colloid-Dark")
    hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
    ${lib.optionalString hasNvidia ''
    -- NVIDIA + Wayland hint (explicit-sync is automatic on recent drivers).
    hl.env("__GL_GSYNC_ALLOWED", "1")''}

    -- — General options —
    hl.config({
      input = {
        kb_layout = "es",
        -- caps:escape — Caps Lock acts as Escape (no Caps Lock function).
        kb_options = "caps:escape",
        -- 2 = keyboard focus only changes on click (focus-follows-mouse off), but
        -- the hovered window still receives pointer events — so you can scroll an
        -- unfocused window under the cursor without it stealing keyboard focus.
        follow_mouse = 2,
        -- macOS-like feel: adaptive accel with a small positive speed gives the
        -- nonlinear, slightly-quicker pointer macOS uses.
        accel_profile = "adaptive",
        sensitivity = 0.2,
        touchpad = {
          -- clickfinger: a physical 2-finger press = RMB, 3-finger = MMB
          -- (replaces libinput's bottom-corner click areas). 2-finger tap
          -- already right-clicks via the default tap_to_click.
          natural_scroll = true,
          clickfinger_behavior = true,
          -- Keep the pad working while typing (moving the pointer or tapping
          -- mid-keystroke); libinput's palm detection still rejects a resting hand.
          disable_while_typing = false,
          -- Under 1 to tame libinput's over-sensitive two-finger scroll and land
          -- closer to macOS's pace, so it neither undershoots nor coasts past.
          scroll_factor = 0.5,
        },
      },
      general = {
        -- gaps_in is applied per window side, so it doubles between two tiled
        -- windows, while gaps_out lands once at the screen edge. 4/8 is what
        -- reads as a uniform 8px everywhere, the niri `gaps 8` geometry.
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        -- The scrolling tape (Hyprland 0.54+ has it in core; no plugin).
        layout = "scrolling",
        resize_on_border = true,
        -- Static Flexoki fallback (blue active / base-700 inactive). The shell's
        -- matugen hypr-border template overrides these with the live wallpaper
        -- palette, both instantly via `hyprctl eval` (post_hook in mixins/dms.nix)
        -- and persistently via the dofile at the bottom of this file. Without a
        -- value here Hyprland's built-in active border is white, which is what
        -- borders would revert to on every reload before the palette applies.
        col = {
          active_border = "rgb(${lib.removePrefix "#" flexoki.accents.blue.d})",
          inactive_border = "rgb(${lib.removePrefix "#" flexoki.base.b700})",
        },
        -- Master switch for screen tearing. Does nothing on its own — a window
        -- must also carry the `immediate` rule (see the steam_app rule below).
        allow_tearing = true,
      },
      -- Scrolling tape behaviour. Deliberately close to niri's column model:
      -- half-width columns by default, the same four preset widths Mod+R cycles,
      -- and a lone column keeps its width (centered) instead of stretching to
      -- fill the screen — flip fullscreen_on_one_column to true for the
      -- Omarchy-style "single window is always full screen" feel.
      scrolling = {
        column_width = 0.5,
        explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
        fullscreen_on_one_column = false,
        -- 1 = fit (scroll the minimum needed to reveal the focused column)
        -- rather than always re-centering it.
        focus_fit_method = 1,
        follow_focus = true,
      },
      -- Trackpad swipe feel (the gestures themselves are registered below).
      gestures = {
        -- A vertical swipe walks past the neighbouring workspace instead of
        -- clamping to it, so one long swipe crosses the stack the way niri's
        -- does. workspace_swipe_invert stays at its default true: that is the
        -- direction where the workspaces follow the fingers.
        workspace_swipe_forever = true,
        scrolling = {
          -- Snapping the pointer into the newly focused window is Hyprland's
          -- default; niri leaves it where you put it, and with follow_mouse = 2
          -- a warped pointer only means the next hover lands somewhere you
          -- didn't aim at.
          move_snap_cursor = false,
        },
      },
      decoration = {
        rounding = 0,
        -- Separates the quake console from the workspace it drops over. Only
        -- applies while a special workspace is on screen, so it costs the
        -- rest of the session nothing, and the console is the only special
        -- workspace here.
        dim_special = 0.6,
        -- Ever-so-slight transparency on every window, active and inactive
        -- alike, so the backdrop blur below has something to show through.
        active_opacity = 0.96,
        inactive_opacity = 0.96,
        blur = {
          enabled = true,
          size = 8,
          passes = 2,
          new_optimizations = true,
        },
      },
      animations = { enabled = true },
      misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        -- When an app opens a link, the browser requests focus via
        -- xdg-activation. Hyprland ignores activation requests by default
        -- (anti-focus-steal), so the link would open with the browser left in
        -- the background. Honour the request instead.
        focus_on_activate = true,
        -- Global VRR off; the desk monitor pins its own vrr = 0 above.
        vrr = 0,
      },
      render = {
        direct_scanout = 1,
        -- Auto-HDR: the desktop stays SDR/8-bit at all times; when a fullscreen
        -- app requests an HDR swapchain, Hyprland flips that output to HDR for
        -- the duration and reverts on exit. 1 = generic BT.2020+PQ; bump to 2
        -- (hdredid, uses the panel's EDID primaries) if HDR colours look off.
        cm_auto_hdr = 1,
      },
      -- eDP-1 runs at fractional scale (1.25) on the g815. XWayland can't do
      -- fractional scaling, so Hyprland upscales X11 surfaces → blurry output
      -- and per-frame upscale overhead. force_zero_scaling makes XWayland render
      -- at scale 1 (crisp, native rate); X11 apps that look small can be nudged
      -- with GDK_SCALE / per-app DPI. No-op on the 1x hosts.
      xwayland = {
        force_zero_scaling = true,
      },
    })

    -- The DualSense touchpad lands in Hyprland's Mouse list, not the touchpad
    -- list, so it inherits the global sensitivity meant for a full-size mouse.
    -- That surface is about 40mm wide, so 0.2 with adaptive accel means a lot
    -- of finger for very little pointer, and slow moves get damped on top of
    -- it. Flat accel plus a hard multiplier makes travel proportional. The
    -- Bluetooth link still costs ~20ms that no setting here can remove; USB
    -- does not have it.
    hl.device({
      name = "dualsense-wireless-controller-touchpad",
      accel_profile = "flat",
      sensitivity = 0.7,
    })

    -- — Animations: spring physics for anything that moves —
    -- The old `snappy` bezier put 75% of the distance into the first 15% of the
    -- duration. That fast part is too quick to read as travel, so the only
    -- motion actually perceived was the shallow tail, which is why everything
    -- looked linear. A spring starts from rest, accelerates, then decelerates
    -- into the target, so the whole path is legible.
    -- At mass 1: zeta = dampening / (2 * sqrt(stiffness)) sets the bounce and
    -- settle time is roughly 4.6 / (zeta * sqrt(stiffness)). `glide` is zeta
    -- 0.85 (~1% overshoot, ~255ms), `firm` is critically damped (no bounce,
    -- ~230ms). A spring derives its duration from those numbers and ignores
    -- `speed`, but hl.animation still rejects the call without one, so each
    -- spring leaf carries the speed matching its settle time.
    hl.curve("glide", { type = "spring", mass = 1, stiffness = 450, dampening = 36 })
    hl.curve("firm",  { type = "spring", mass = 1, stiffness = 400, dampening = 40 })
    -- Opacity and border colour must not overshoot, so they stay on a bezier.
    -- Durations are in ds (1 ds = 100ms).
    hl.curve("eased", { type = "bezier", points = { { 0.4, 0 }, { 0.2, 1 } } })

    -- Workspaces slide vertically, matching niri's stacked-workspace model:
    -- switching pushes the next one up or down.
    hl.animation({ leaf = "windows",          enabled = true, spring = "glide", speed = 2.6 })
    hl.animation({ leaf = "windowsOut",       enabled = true, spring = "firm",  speed = 2.3, style = "popin 90%" })
    hl.animation({ leaf = "layers",           enabled = true, spring = "firm",  speed = 2.3 })
    hl.animation({ leaf = "fade",             enabled = true, bezier = "eased", speed = 2.5 })
    hl.animation({ leaf = "border",           enabled = true, bezier = "eased", speed = 5 })
    hl.animation({ leaf = "workspaces",       enabled = true, spring = "glide", speed = 2.6, style = "slidevert" })
    hl.animation({ leaf = "specialWorkspace", enabled = true, spring = "glide", speed = 2.6, style = "slidevert" })

    -- — Trackpad gestures (niri's set, 1:1 under the fingers) —
    -- Horizontal scrolls the tape, vertical walks workspaces: the same split
    -- niri had, and the one the tape/stack geometry implies. `scroll_move` is
    -- the scrolling layout's own gesture (0.56+): it drags the tape 1:1, then
    -- projects the release velocity and snaps to a column, so a flick carries.
    -- Both stay on 3 fingers: niri's four-finger overview swipe has no
    -- equivalent, Hyprland has no overview. A directional ("up") gesture would
    -- shadow the vertical one over half the axis, which is why fullscreen went
    -- keyboard-only (Mod+Shift+F).
    hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })
    hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })

    -- — Keybinds (mirror the macOS/aerospace muscle memory, SUPER as mod) —
    ${shellBinds}

    hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
    -- Reclaim the laptop's Copilot key: it launches Claude, not Copilot.
    -- Microsoft's spec (which ASUS honours) has the key emit Meta+Shift+F23;
    -- this drops a fresh local ghostty into `claude`, cwd'd at the nix config.
    hl.bind(mod .. " + SHIFT + F23", hl.dsp.exec_cmd("ghostty --working-directory=${config.home.homeDirectory}/.config/nix -e claude"))
    hl.bind(mod .. " + Q", hl.dsp.window.close())
    hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }))
    hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
    hl.bind(mod .. " + B", hl.dsp.exec_cmd("zen-beta"))

    -- Vim-style focus/move (aerospace alt-hjkl), mapped onto the scrolling
    -- tape's column model: H/L walk columns (layout-aware, so they wrap and
    -- scroll the tape rather than jumping to a neighbouring monitor), J/K walk
    -- windows stacked inside the focused column.
    hl.bind(mod .. " + H", hl.dsp.layout("focus l"))
    hl.bind(mod .. " + L", hl.dsp.layout("focus r"))
    hl.bind(mod .. " + J", hl.dsp.focus({ direction = "d" }))
    hl.bind(mod .. " + K", hl.dsp.focus({ direction = "u" }))
    hl.bind(mod .. " + SHIFT + H", hl.dsp.layout("swapcol l"))
    hl.bind(mod .. " + SHIFT + L", hl.dsp.layout("swapcol r"))
    hl.bind(mod .. " + SHIFT + J", hl.dsp.window.swap({ direction = "d" }))
    hl.bind(mod .. " + SHIFT + K", hl.dsp.window.swap({ direction = "u" }))

    -- Column width. F = full width with gaps (niri's maximize-column), M = true
    -- maximize to the edges, R = cycle the explicit_column_widths presets,
    -- minus/plus = ±10%.
    hl.bind(mod .. " + F", hl.dsp.layout("colresize 1.0"))
    hl.bind(mod .. " + M", hl.dsp.window.fullscreen({ action = "toggle", mode = "maximized" }))
    hl.bind(mod .. " + R", hl.dsp.layout("colresize +conf"))
    hl.bind(mod .. " + minus", hl.dsp.layout("colresize -0.1"))
    hl.bind(mod .. " + plus", hl.dsp.layout("colresize +0.1"))

    -- Tape housekeeping: C scrolls the focused column fully into view; comma
    -- pulls the focused window into the previous column (or expels it back out
    -- if it isn't alone), SHIFT+comma does the same against the next column.
    hl.bind(mod .. " + C", hl.dsp.layout("fit_into_view"))
    hl.bind(mod .. " + comma", hl.dsp.layout("consume_or_expel prev"))
    hl.bind(mod .. " + SHIFT + comma", hl.dsp.layout("consume_or_expel next"))

    -- Workspaces by id, addressed as `code:N` (keycodes, not keysyms) so the
    -- es layout's shifted number row can't break the SHIFT variants.
    for i = 1, 9 do
      hl.bind(mod .. " + code:" .. (i + 9), hl.dsp.focus({ workspace = tostring(i) }))
      hl.bind(mod .. " + SHIFT + code:" .. (i + 9), hl.dsp.window.move({ workspace = tostring(i), follow = true }))
    end

    hl.bind(mod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))

    -- Alt-Tab. Hyprland has no most-recently-used hold-and-cycle switcher
    -- (niri's `recent-windows`), so this is a plain stack cycle: each press
    -- steps one window, SHIFT reverses. Alt+grave (cycle windows of the same
    -- app) has no equivalent and is dropped.
    hl.bind("ALT + Tab", hl.dsp.window.cycle_next())
    hl.bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))

    -- MX Master 3S, usable without the keyboard. Its three thumb buttons are
    -- remapped to keys in modules/nixos/mixins/mouse.nix: the gesture button is
    -- Mod, so thumb + main wheel walks workspaces, and back/forward arrive as
    -- KEY_F13/KEY_F14 and walk columns. Binds match keysyms, not keycodes, and
    -- the es layout gives those two XF86Tools and XF86Launch5 (it has no F13/F14
    -- keysym at all). Check with
    -- `xkbcli compile-keymap --layout es | rg 'key <FK1[34]>'` before touching
    -- either half.
    hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
    hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
    hl.bind("XF86Tools", hl.dsp.layout("focus l"))
    hl.bind("XF86Launch5", hl.dsp.layout("focus r"))

    -- Mouse drag/resize (aerospace SUPER+LMB move, SUPER+RMB resize).
    hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
    hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
    ${lib.optionalString hasNvidia ''

    -- Confirm the pending GPU-relog prompt (fallback for a notification daemon
    -- without action buttons). See gpuRelogPrompt / powerTune in hyprland.nix.
    hl.bind(mod .. " + SHIFT + BackSpace", hl.dsp.exec_cmd("${gpuRelogPrompt}/bin/gpu-relog-prompt confirm"))''}

    -- — Window → workspace rules (Linux app classes; Hyprland matches `class`) —
    -- No `silent`: when one of these apps opens, Hyprland follows the window to
    -- its assigned workspace. No terminal rule — ghostty opens where you are.
    -- zen-beta: the wrapper launches with `--name zen-beta` (desktop file),
    -- bare `zen` covers manual CLI launches.
    hl.window_rule({ match = { class = "^([Hh]elium|zen(-beta)?)$" }, workspace = "1" })
    hl.window_rule({ match = { class = "^([Cc]ode|[Zz]ed|dev.zed.Zed)$" }, workspace = "3" })
    hl.window_rule({ match = { class = "^([Ss]lack|WhatsApp|[Ee]quibop|discord|[Bb]eeper|[Bb]lue[Bb]ubbles)$" }, workspace = "4" })
    -- Beeper/BlueBubbles (Electron) map their main window floating, so they
    -- never tile. Force them back into the layout.
    hl.window_rule({ match = { class = "^([Bb]eeper)$" }, float = false })
    hl.window_rule({ match = { class = "^([Bb]lue[Bb]ubbles)$" }, float = false })
    hl.window_rule({ match = { class = "^([Oo]bsidian)$" }, workspace = "5" })
    hl.window_rule({ match = { class = "^([Cc]laude)$" }, workspace = "7" })
    hl.window_rule({ match = { class = "^([Ss]potify|[Kk]opuz)$" }, workspace = "8" })
    hl.window_rule({ match = { class = "^([Ss]team|steam)$" }, workspace = "9" })
    -- Allow tearing for Steam games (any steam_app_<id> window). Pairs with
    -- general.allow_tearing to present frames immediately instead of on the
    -- vblank. Tearing only actually happens when the game itself presents
    -- without vsync, so launch games with vsync OFF.
    hl.window_rule({ match = { class = "^(steam_app_.*)$" }, immediate = true })

    -- — Chromium/helium auxiliary popups: float, pin across every workspace, and
    --   tuck into a corner. `pin` is Hyprland's "show on all workspaces" — niri
    --   had no equivalent, so these used to just float. helium gives these three
    --   windows distinct identities, captured live with `hyprctl clients`:
    --     • Video PiP      → class "" (empty), title "Picture in picture"
    --     • Built-in notif → class "" (empty), title "" (empty)
    --     • Document PiP   → class "helium", maps floating, dynamic page title
    --   Matching is on creation-time class/title, which is why a
    --   `title:Picture-in-Picture` rule never fires: the real title is
    --   "Picture in picture" (spaces, not hyphens) and the class is empty.
    --
    -- Video PiP → float, pin, bottom-right, capped to ~28% (it opens ~1240px wide).
    hl.window_rule({ match = { title = "^([Pp]icture[ -][Ii]n[ -][Pp]icture)$" },
      float = true, pin = true,
      size = { "(monitor_w*0.28)", "(monitor_h*0.28)" },
      move = { "(monitor_w-window_w-16)", "(monitor_h-window_h-16)" } })
    -- Document PiP (and any other floating helium popup) → pin + sane size
    -- (Meet's document PiP opens ~1240x1110) + bottom-right. Matched on floating
    -- state, so normal *tiled* browser windows are untouched.
    hl.window_rule({ match = { class = "^(helium)$", float = true },
      pin = true,
      size = { "(monitor_w*0.28)", "(monitor_h*0.28)" },
      move = { "(monitor_w-window_w-16)", "(monitor_h-window_h-16)" } })
    -- Chrome built-in notification → empty class AND empty title. Float (it
    -- tiles otherwise — a calendar alert wrecking the layout), pin, top-right.
    -- The empty title is what sets it apart from the video PiP above.
    hl.window_rule({ match = { class = "^$", title = "^$" },
      float = true, pin = true,
      move = { "(monitor_w-window_w-16)", "16" } })
    -- GNOME spacebar quick-preview (Sushi / NautilusPreviewer) → float + center
    -- so it pops up like macOS Quick Look instead of tiling into the layout. It
    -- sizes itself to the previewed content, so no size rule.
    hl.window_rule({ match = { class = "^(org.gnome.NautilusPreviewer)$" },
      float = true, center = true })

    -- — Border colours: persist the last wallpaper palette across reloads —
    -- The shell renders the live wallpaper-derived border colours to
    -- ~/.cache/dank/hypr-border.lua on every palette change and also pushes them
    -- live via `hyprctl eval` (see the matugen template in mixins/dms.nix). That
    -- eval is runtime-only, so a `hyprctl reload` (or the startup race before the
    -- first palette render) would drop back to the static Flexoki fallback in
    -- `general.col` above. Re-applying the cache file here on every config eval
    -- keeps the wallpaper colours instead. pcall: the file is absent before the
    -- first render — fall through to the fallback rather than erroring the whole
    -- config, which would leave the session unusable.
    pcall(dofile, os.getenv("HOME") .. "/.cache/dank/hypr-border.lua")
  '';

  # — Session environment (uwsm) —
  #
  # uwsm sources ~/.config/uwsm/env and ~/.config/uwsm/env-${XDG_CURRENT_DESKTOP,,}
  # once per login, before launching Hyprland, and imports the result into the
  # systemd user manager. That second half is what makes this the right home for
  # anything the *autostarted user services* also need: they do not inherit
  # Hyprland's own `hl.env` block.
  xdg.configFile."uwsm/env".text = ''
    export QS_ICON_THEME="Colloid-Dark"
    export QT_QPA_PLATFORMTHEME="qt6ct"
  '';

  # — Multi-GPU selection (hybrid laptop) —
  #
  # The g815 is a hybrid laptop: the Intel iGPU (PCI 0000:00:02.0) drives the
  # internal panel (eDP-1), while the NVIDIA dGPU (PCI 0000:02:00.0) drives the
  # external ports — including HDMI-A-1, the 1440p144 desk monitor.
  #
  # The session is ALWAYS iGPU-primary. Gaming lives on Windows; on Linux the
  # dGPU is nothing but a power-managed peripheral for the panel backlight (its
  # WMI) and the HDMI port. AQ_DRM_DEVICES is a ':'-separated device list; the
  # FIRST entry becomes the primary GPU (aquamarine src/backend/drm/DRM.cpp).
  # When the dGPU is powered at login (we were charging) it is listed SECOND — a
  # scanout-only head for the desk monitor, fed by an iGPU→dGPU blit (trivial for
  # desktop work). When it's absent (battery boot) only the iGPU is listed, so
  # nothing in the session ever touches the nvidia stack and the chip can be hard
  # powered off.
  #
  # Keyed on device PRESENCE, not the power source — it cannot disagree with
  # reality. The set is frozen at aquamarine init, so the only situations that
  # want a different set mid-session go through the consent popup
  # (gpu-relog-prompt above), never an automatic relog. This file records the
  # chosen set in $XDG_RUNTIME_DIR/session-gpu-mode (igpu | igpu+dgpu) for it.
  #
  # GPUs are resolved through the stable by-path PCI symlinks (DRM card numbers
  # can reorder across boots) back to the canonical /dev/dri/cardN nodes that
  # aquamarine enumerates and matches against.
  xdg.configFile."uwsm/env-hyprland" = lib.mkIf hasNvidia {
    text = ''
      dgpu=$(readlink -f /dev/dri/by-path/pci-0000:02:00.0-card 2>/dev/null)
      igpu=$(readlink -f /dev/dri/by-path/pci-0000:00:02.0-card 2>/dev/null)
      vendors=/run/opengl-driver/share/glvnd/egl_vendor.d

      mode=igpu
      if [ -n "$igpu" ] && [ -n "$dgpu" ]; then
        export AQ_DRM_DEVICES="$igpu:$dgpu"
        # Cross-GPU scanout must survive suspend: after s2idle the dGPU side can
        # re-export buffers with a tiling modifier the peer can't import
        # (EGL_BAD_MATCH → permanently stuck pageflip). A LINEAR intermediate
        # buffer for the multi-GPU blit is modifier-independent, so the
        # iGPU→dGPU HDMI copy keeps working across resume.
        export AQ_FORCE_LINEAR_BLIT=1
        # The compositor MUST be able to load nvidia's EGL here. HDMI-A-1 hangs
        # off the dGPU, so aquamarine builds a SECOND renderer on that node to
        # blit the iGPU-rendered frame across for scanout. uwsm feeds this file
        # to the compositor as well as to the user manager, so a Mesa-only
        # vendor list breaks that renderer and the desk monitor goes black:
        # eglInitialize fails with EGL_NOT_INITIALIZED ("DRI2: failed to load
        # driver") → "Failed to initialize renderer backend for blitting" → the
        # connector modesets at the right mode in an endless loop and never
        # receives a frame (observed 2026-08-17, the whole log was that loop).
        # glvnd walks this list in order, so nvidia first matches the system
        # default precedence. Clients inherit it too — that is the accepted
        # cost of uwsm's single env file; the Electron apps that actually
        # misbehave are pinned per-app by lib/chromium-igpu.nix.
        export __EGL_VENDOR_LIBRARY_FILENAMES="$vendors/10_nvidia.json:$vendors/50_mesa.json"
        mode="igpu+dgpu"
      elif [ -n "$igpu" ]; then
        # dGPU powered off (battery boot): name ONLY the iGPU. Leaving
        # AQ_DRM_DEVICES unset is NOT enough if the card reappears — aquamarine
        # would probe every card and Xwayland would grab the nvidia node,
        # pinning it at D0. With only the iGPU named, the session never touches
        # the nvidia stack; gpu-relog-prompt offers a relog if a monitor shows
        # up wanting it.
        export AQ_DRM_DEVICES="$igpu"
        # No dGPU in the session at all, so nothing needs nvidia's EGL and a
        # Mesa-only list keeps every client off the nvidia render node (their
        # GPU processes enumerate vendors independently and would otherwise
        # open it, pinning the chip at D0 and parking ~2 GB of VRAM on it —
        # observed live 2026-07-26).
        export __EGL_VENDOR_LIBRARY_FILENAMES="$vendors/50_mesa.json"
      fi
      if [ -n "''${XDG_RUNTIME_DIR:-}" ]; then
        printf '%s\n' "$mode" > "$XDG_RUNTIME_DIR/session-gpu-mode" 2>/dev/null || true
      fi

      # VA-API video decode on the iGPU, always — no app should wake the dGPU
      # for video. Offloaded apps (pkgs.nvidiaOffloadEnv) still force nvidia
      # themselves when explicitly asked.
      export LIBVA_DRIVER_NAME=iHD
      # Vulkan stays Intel-only unconditionally: unlike EGL this is never needed
      # by the compositor (aquamarine renders through EGL/GBM), so pinning it
      # costs nothing and still keeps Vulkan clients off the dGPU. Offloaded
      # apps set their own ICD via nvidiaOffloadEnv.
      export VK_DRIVER_FILES=/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json
      export VK_ICD_FILENAMES="$VK_DRIVER_FILES"
    '';
  };

  # Power automation (see powerTune in the let block): refresh rate, keyboard
  # aura and the relog prompt all follow AC/battery. Bound to
  # graphical-session.target so it starts and stops with the Hyprland session
  # and inherits HYPRLAND_INSTANCE_SIGNATURE (uwsm finalises it into the systemd
  # user manager) — hyprctl needs it.
  systemd.user.services.power-tune = lib.mkIf hasNvidia {
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

  # polkit auth agent: FormalShell registers its own in-shell agent (M16,
  # 2026-08-03), so there is no standalone agent service here. Two agents would
  # race for the session registration.

  # Compositor-essential session packages. The generic GNOME/desktop apps and
  # their MIME defaults live in users/kyandesutter/mixins/desktop-apps.nix.
  #   • wl-clip-persist: keeps the regular Wayland selection alive after the
  #     source app exits so the shell's clipboard poller can capture it
  #     (launched from autostart.nix).
  home.packages = with pkgs; [
    wl-clip-persist

    # GTK theme the shell's gtk template sets via gsettings/dconf (adw-gtk3-dark).
    # Installed here so that theme name resolves; the shell, not the gtk module,
    # selects it (see the dark-mode block below).
    adw-gtk3

    # Icon themes. Colloid-Dark is the desktop-wide icon set (set via gtk.iconTheme
    # below, plus qt{5,6}ct.conf + QS_ICON_THEME above for Qt). adwaita is kept
    # as the complete freedesktop fallback so any icon Colloid lacks resolves
    # to a real glyph instead of the broken-image placeholder.
    colloid-icon-theme
    adwaita-icon-theme

    # Qt platform theme engines. QT_QPA_PLATFORMTHEME=qt6ct (uwsm/env above)
    # points Qt6 apps at qt6ct; qt5ct themes Qt5 apps. Both read the shell's
    # generated colour scheme via the qt{6,5}ct.conf written in mixins/qt.nix.
    kdePackages.qt6ct
    libsForQt5.qt5ct
  ];

  # Cursor theme — Bibata Modern Classic, the black variant. Sets it for GTK,
  # native Wayland (hyprcursor) and X11/XWayland (x11.enable exports
  # XCURSOR_THEME/SIZE), so every app shows the same cursor; the hl.env pair
  # above covers XWayland clients Hyprland spawns itself.
  home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
    hyprcursor.enable = true;
  };

  # Dark mode for GTK / X11 / browsers.
  #
  # The shell owns app theming (see the matugen config.toml + templates in
  # dms.nix, plus DMS's own builtin gtk template). The builtin gtk3/gtk4
  # templates write the palette to ~/.config/gtk-{3,4}.0/dank-colors.css
  # (imported via gtk.css), and DMS drives the *runtime* dark signal on every
  # re-theme — `gsettings set org.gnome.desktop.interface color-scheme
  # prefer-dark` + `gtk-theme adw-gtk3-dark` (also written to dconf).
  # xdg-desktop-portal reports that to native-Wayland libadwaita/GTK4 apps. So
  # we don't pin the theme *name* here — the shell chooses it, and pinning our
  # own would drift.
  #
  # We keep this module for the things the shell does NOT do:
  #   • gtk.iconTheme — sets Colloid-Dark as the icon theme. Neither shell
  #     touches the icon theme; without this GTK falls back to hicolor and
  #     renders every app/mime icon as the broken-image placeholder.
  #   • gtk-application-prefer-dark-theme in settings.ini — the X11/XWayland
  #     fallback (no xsettingsd here). DMS's gtk theming only touches
  #     gtk.css + gsettings/dconf, never settings.ini.
  #   • gtk.font — the UI font (gtk-font-name in both settings.ini files).
  #     GTK3 under Wayland and GTK4 read it from there; GNOME/libadwaita apps
  #     read org.gnome.desktop.interface instead, so the same pair is written to
  #     dconf below. Without both, half the GTK apps stay on the fontconfig
  #     sans-serif default and the desktop looks mixed.
  #   • gtk{3,4}.extraCss — own gtk.css declaratively so it holds ONLY the
  #     palette import. The shell writes the colour file but never gtk.css, so
  #     an unmanaged gtk.css silently accumulates cruft: stale @define-color
  #     blocks from old theming tools end up ABOVE the import, and GTK
  #     requires @import before any other rule — so it drops the import, the
  #     colour file never loads, and GTK3 apps render un-themed adw-gtk3-dark.
  #     Managing the file keeps the import valid and first.
  #
  # FormalShell hosts get the same treatment with FormalShell's names: its
  # ThemeEngine renders formalshell-colors.css (gtk template) + the qt{5,6}ct
  # matugen.conf, and asserts color-scheme/gtk-theme via dconf on every
  # retheme, flipping adw-gtk3 ↔ adw-gtk3-dark with the mode. The static
  # settings.ini prefer-dark hint is DMS-only: FormalShell has a real light
  # mode, and the hint would keep X11/XWayland GTK3 fallback apps dark in it.
  gtk = {
    enable = true;
    iconTheme = {
      name = "Colloid-Dark";
      package = pkgs.colloid-icon-theme;
    };
    font = {
      name = "MEK Sans";
      size = 11;
    };
    gtk3.extraConfig = lib.optionalAttrs (!useFormalshell) { gtk-application-prefer-dark-theme = 1; };
    gtk4.extraConfig = lib.optionalAttrs (!useFormalshell) { gtk-application-prefer-dark-theme = 1; };
    gtk3.extraCss = ''@import url("${if useFormalshell then "formalshell-colors.css" else "dank-colors.css"}");'';
    gtk4.extraCss = ''@import url("${if useFormalshell then "formalshell-colors.css" else "dank-colors.css"}");'';
  };

  # The GSettings half of the GTK font (see the gtk block above). The shell
  # writes gtk-theme and color-scheme into this same schema at runtime; these
  # keys are disjoint from those, so neither side clobbers the other.
  dconf.settings."org/gnome/desktop/interface" = {
    font-name = "MEK Sans 11";
    monospace-font-name = "MEK Mono 12";
    document-font-name = "MEK Sans 11";
  };
}
