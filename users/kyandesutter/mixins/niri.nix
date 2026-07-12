{ pkgs, config, lib, inputs, options, ... }:
let
  noctaliaBin = "${config.programs.noctalia.package}/bin/noctalia";

  # Workspace pill labels: role → Nerd Font glyph + short name, mirroring the
  # macOS aerospace workspace names (see mixins/aerospace.nix). niri-flake orders
  # workspaces by attr *key* (kept "1"–"9" below); the workspace `name` is what
  # the Mod+N binds and the window-rules target and what Noctalia renders on each
  # pill (widget.workspaces.display = "name", max_label_chars in noctalia.nix).
  # Glyph and name are joined by an EM SPACE (\u2003), not an ASCII space —
  # Noctalia collapses ASCII/nbsp whitespace in the label but preserves it.
  # Written as JSON \u escapes so the private-use glyphs survive editing; glyphs
  # verified present in GeistMono Nerd Font 3.4.0.
  wsName = builtins.fromJSON ''
    {"1": "\uf0ac\u2003web", "2": "\uf120\u2003term", "3": "\uf121\u2003dev", "4": "\uf086\u2003chat", "5": "\uf0b1\u2003prod", "6": "\uf02f\u2003print", "7": "\udb81\udea9\u2003ai", "8": "\uf001\u2003media", "9": "\uf11b\u2003game"}
  '';

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
  #     noctalia.nix), passing the cached wallpaper accent. ac=static,
  #     powerbank=breathe ("charging" vibe), battery=dark.
  #   - refresh rate: eDP-1 is 2560x1600@240Hz; drop to 60Hz whenever the active
  #     PPD profile is power-saver, restore 240Hz otherwise. Refresh follows the
  #     *profile* (not the source) so a manual Noctalia power-saver toggle also
  #     drops to 60Hz. niri has no runtime per-output IPC, so the mode is set by
  #     rewriting the eDP-1 KDL fragment (include'd from config.kdl) and asking
  #     niri to reload — see set_refresh below.
  #   - relog consent prompt: every event re-runs gpu-relog-prompt (below),
  #     which decides whether a dGPU-release relog is worth OFFERING (persistent
  #     notification, user confirms or dismisses — NEVER automatic).
  #   - dGPU convergence kick: once at startup, `systemctl start
  #     dgpu-reconcile.service` (polkit rule in power.nix) so a fresh login
  #     finally powers off a dGPU a previous session was holding.
  #
  # Event-driven, no polling: three monitors feed one loop through a single
  # process substitution (which keeps the loop in this shell so last_src/
  # last_rate persist) — inotifywait on /run/power/state for source changes,
  # dbus-monitor on PPD for profile changes (the refresh follow), and udevadm
  # on the drm subsystem for monitor/GPU hotplug (niri hot-adds the dGPU's DRM
  # device by itself; this loop only needs the event to re-run the prompt).
  # The inner `wait` keeps the substitution alive while the backgrounded
  # monitors run.
  powerTune = pkgs.writeShellApplication {
    name = "power-tune";
    runtimeInputs = with pkgs; [
      niri # niri msg
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

      # The eDP-1 output block lives in this fragment, include'd (optional=true)
      # from config.kdl — the typed settings deliberately don't declare eDP-1,
      # so this file is its sole owner. niri matches the requested refresh to
      # the closest real mode. Write-then-rename keeps the reload atomic.
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
          # Repaint the keyboard for the new source via the shared setter (in the
          # home profile — user services have a limited PATH, so reference it
          # absolutely), using the cached wallpaper accent (fall back to the seed).
          colour="$(cat "$HOME/.cache/noctalia/aura-color" 2>/dev/null || echo b15bf5)"
          ${config.home.profileDirectory}/bin/aura-repaint "$colour" || true
          last_src="$src"
        fi
        case "$(profile)" in
          power-saver) set_refresh 60 ;;
          *)           set_refresh 240 ;;
        esac
        # Consent popup (self-guarding: single instance, remembers dismissals,
        # no-ops when the session already fits the situation). Backgrounded so
        # this loop stays responsive; on a confirmed relog it quits niri, which
        # tears this unit down with the session.
        ${gpuRelogPrompt}/bin/gpu-relog-prompt &
      }

      # Converge dGPU power for THIS login: a popup-confirmed relog happens
      # long after the battery event that wanted the dGPU off, so the fresh
      # session kicks the (start-only, serialized) system reconciler once.
      # Passwordless via a polkit rule scoped to exactly this unit+verb
      # (modules/nixos/mixins/power.nix).
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
        # GPU/monitor hotplug (drm "change" uevents). udevadm via the system
        # profile — user services have a limited PATH.
        /run/current-system/sw/bin/udevadm monitor --udev --subsystem-match=drm 2>/dev/null &
        wait
      } )
    '';
  };

  # Battery-only consent relog prompt — the ONLY path that frees the dGPU for
  # power-off. niri hot-adds the dGPU's DRM device at runtime (a monitor on the
  # powered dGPU just works — the old `monitor` relog branch is gone with
  # Hyprland), but niri also opens a renderer fd on every GPU it sees and has
  # no release IPC. So once the dGPU has appeared in this session,
  # `modprobe -r nvidia*` stays blocked until the session ends — and on battery
  # that idle dGPU is a large drain. Hence: OFFER (never force) a relog. No
  # countdown, no default action: a persistent notification with [Relog now]/
  # [Not now] buttons (Noctalia's daemon supports actions via notify-send -A;
  # Super+Shift+BackSpace is a belt-and-braces confirm for a daemon that
  # doesn't). A dismissal is remembered and never re-prompted until the
  # situation clears (the `dismissed` file is dropped whenever evaluate()
  # says `none`).
  gpuRelogPrompt = pkgs.writeShellApplication {
    name = "gpu-relog-prompt";
    runtimeInputs = with pkgs; [ libnotify coreutils util-linux niri ];
    text = ''
      rt="''${XDG_RUNTIME_DIR:-/tmp}"
      confirm="$rt/gpu-relog.confirm"
      dismissed="$rt/gpu-relog.dismissed"
      outfile="$rt/gpu-relog.action"

      # Keybind fallback: Super+Shift+BackSpace drops the confirm flag.
      if [ "''${1:-}" = confirm ]; then : > "$confirm"; exit 0; fi

      # battery + the dGPU's DRM device present (niri holds it — the node only
      # exists while the nvidia modules are loaded) + no monitor connected on
      # any of its connectors → a relog would let dgpu-reconcile power it off.
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
      # Already dismissed for this situation → stay quiet.
      [ -e "$dismissed" ] && exit 0

      # One prompt at a time.
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
        *) : > "$dismissed"; exit 0 ;;
      esac

      # Re-check right before acting — the situation may have evaporated
      # between click and here.
      [ "$(evaluate)" = "$need" ] || exit 0
      notify-send -t 2000 "GPU mode" "Relogging…" || true
      niri msg action quit --skip-confirmation
    '';
  };
in
{
  # niri is enabled at the system level (programs.niri in
  # modules/nixos/mixins/niri.nix); this module owns the user config via
  # niri-flake's typed settings (programs.niri.settings → KDL, checked with
  # `niri validate` at build time so config errors fail the rebuild, not the
  # login). The binary is nixpkgs' niri (26.04) on both sides.
  imports = [ inputs.niri.homeModules.niri ];

  programs.niri = {
    enable = true;
    package = pkgs.niri; # nixpkgs 26.04 — also the binary `niri validate` runs

    settings = {
      input = {
        keyboard.xkb = {
          layout = "es";
          # caps:escape — Caps Lock acts as Escape (no Caps Lock function).
          options = "caps:escape";
        };
        touchpad = {
          # clickfinger: a physical 2-finger press = RMB, 3-finger = MMB
          # (replaces libinput's bottom-corner click areas). scroll-factor < 1
          # dampens the over-sensitive, long-coasting two-finger scroll.
          tap = true;
          natural-scroll = true;
          click-method = "clickfinger";
          scroll-factor = 0.4;
        };
        # focus-follows-mouse stays off (niri default) — keyboard focus only
        # changes on click, matching the old follow_mouse=2 behaviour; niri
        # already scrolls the hovered window without focusing it.
      };

      # Desk monitor: ASUS PA278CGV (1440p144) wired to the dGPU. Its
      # EDID-preferred timing is 60Hz; refresh is omitted so niri picks the
      # highest rate for the resolution (144) without exact-float matching.
      # Placed at the ORIGIN (0x0) so it is the *primary* display, and
      # focus-at-startup lands the session there when docked. VRR off: the
      # panel stays locked at a steady 144Hz (vrr=1 flickered on the desktop,
      # vrr=2 chased the framerate in games — and gaming lives on Windows now).
      #
      # eDP-1 (internal 18" WQXGA 240Hz, to the RIGHT at x=2560, scale 1.25) is
      # deliberately ABSENT here: its output block lives in the power-tune
      # fragment (~/.cache/power-tune/edp-refresh.kdl, see the raw-KDL appendix
      # below) so the refresh-follows-profile flip can own it.
      outputs."HDMI-A-1" = {
        mode = { width = 2560; height = 1440; };
        position = { x = 0; y = 0; };
        scale = 1.0;
        focus-at-startup = true;
      };

      # Named workspaces "1"–"9", mirroring the macOS/aerospace assignment:
      # communication (4) and media (8) live on the internal panel (eDP-1); the
      # rest on the desk monitor (HDMI-A-1). When HDMI-A-1 is absent niri moves
      # its workspaces to eDP-1 and back on reconnect.
      workspaces = lib.listToAttrs (map (i: {
        name = toString i;                            # attr key → sort/position 1–9
        value = {
          name = wsName.${toString i};                # workspace name → pill label + ref
          open-on-output = if i == 4 || i == 8 then "eDP-1" else "HDMI-A-1";
        };
      }) (lib.range 1 9));

      # — Keybinds (mirror the macOS/aerospace muscle memory, SUPER as mod) —
      binds = {
        # App launcher / clipboard / emoji / theme / lock via noctalia IPC
        # (absolute path — niri spawns argv directly, no shell).
        "Mod+Space".action.spawn = [ noctaliaBin "msg" "panel-toggle" "launcher" ];
        "Mod+Return".action.spawn = "ghostty";
        "Mod+Q".action.close-window = [ ];
        "Mod+Shift+F".action.fullscreen-window = [ ];
        "Mod+V".action.toggle-window-floating = [ ];
        "Mod+B".action.spawn = "helium";
        # ñ is a dedicated key on the es layout; its XKB keysym is `ntilde`.
        "Mod+ntilde".action.spawn = [ noctaliaBin "msg" "panel-toggle" "clipboard" ];
        "Mod+Period".action.spawn = [ noctaliaBin "msg" "panel-toggle" "launcher" "/emo" ];
        "Mod+Shift+T".action.spawn = [ noctaliaBin "msg" "theme-mode-toggle" ];
        # Sleep: lock then suspend on demand, so resume lands on the lock screen.
        "Mod+Shift+Escape".action.spawn = [ noctaliaBin "msg" "session" "lock-and-suspend" ];
        # Confirm the pending GPU-relog prompt (fallback for a notification
        # daemon without action buttons). See gpuRelogPrompt above.
        "Mod+Shift+BackSpace".action.spawn = [ "${gpuRelogPrompt}/bin/gpu-relog-prompt" "confirm" ];

        # Vim-style focus/move (aerospace alt-hjkl), mapped onto niri's column
        # model: H/L walk columns, J/K walk windows inside a column.
        "Mod+H".action.focus-column-left = [ ];
        "Mod+J".action.focus-window-down = [ ];
        "Mod+K".action.focus-window-up = [ ];
        "Mod+L".action.focus-column-right = [ ];
        "Mod+Shift+H".action.move-column-left = [ ];
        "Mod+Shift+J".action.move-window-down = [ ];
        "Mod+Shift+K".action.move-window-up = [ ];
        "Mod+Shift+L".action.move-column-right = [ ];

        "Mod+Tab".action.focus-workspace-previous = [ ];

        # niri-native essentials (no Hyprland equivalent): overview, column
        # maximize, true maximize, preset/relative column widths.
        "Mod+O" = { repeat = false; action.toggle-overview = [ ]; };
        "Mod+F".action.maximize-column = [ ];
        "Mod+M".action.maximize-window-to-edges = [ ];
        "Mod+R".action.switch-preset-column-width = [ ];
        "Mod+Minus".action.set-column-width = "-10%";
        "Mod+Plus".action.set-column-width = "+10%";

        # Screenshots via noctalia (owner rule: when the shell has the feature,
        # prefer it over the compositor's built-in — it's WM-agnostic, so the
        # binds survive compositor changes). niri's own screenshot UI remains
        # available via `niri msg action screenshot` if ever wanted. Print =
        # whole screen; Mod+Shift+S = region picker (macOS Cmd+Shift+4).
        "Print".action.spawn = [ noctaliaBin "msg" "screenshot-fullscreen" ];
        "Mod+Shift+S".action.spawn = [ noctaliaBin "msg" "screenshot-region" ];

        # Volume / brightness / media all route through noctalia (msg IPC) so
        # they share one OSD and stay in sync with the shell:
        #   • volume / mic → speaker + mic, with the volume OSD.
        #   • brightness   → whichever monitor the CURSOR is on (`current`), in
        #     clean 10% steps; external monitor over DDC/CI (noctalia.nix sets
        #     [brightness] enable_ddcutil), internal via the backlight backend.
        #   • media        → the ACTIVE MPRIS player noctalia tracks, so the
        #     keys follow Spotify, not a background YouTube tab.
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
        # Workspaces by NAME (the glyphs in wsName, declared above) — a string
        # arg targets the named workspace, an int would target the per-output
        # index. Mod+N still maps to the workspace keyed N (order preserved).
        { name = "Mod+${toString i}"; value.action.focus-workspace = wsName.${toString i}; }
        { name = "Mod+Shift+${toString i}"; value.action.move-column-to-workspace = wsName.${toString i}; }
      ]) (lib.range 1 9)));

      # — Window → workspace rules (Linux app classes; niri matches app-id).
      # No terminal rule: ghostty opens on the active workspace.
      window-rules = [
        { matches = [ { app-id = "^([Hh]elium)$"; } ]; open-on-workspace = wsName."1"; } # web
        { matches = [ { app-id = "^([Cc]ode|[Zz]ed|dev.zed.Zed)$"; } ]; open-on-workspace = wsName."3"; } # development
        { matches = [ { app-id = "^([Ss]lack|WhatsApp|[Ee]quibop|discord|[Bb]eeper|[Bb]lue[Bb]ubbles)$"; } ]; open-on-workspace = wsName."4"; } # communication
        # Beeper/BlueBubbles (Electron) map their main window floating, so they
        # never tile. Force them back into the layout.
        { matches = [ { app-id = "^([Bb]eeper)$"; } ]; open-floating = false; }
        { matches = [ { app-id = "^([Bb]lue[Bb]ubbles)$"; } ]; open-floating = false; }
        { matches = [ { app-id = "^([Cc]laude)$"; } ]; open-on-workspace = wsName."7"; } # ai
        { matches = [ { app-id = "^([Ss]potify)$"; } ]; open-on-workspace = wsName."8"; } # media
        { matches = [ { app-id = "^([Ss]team|steam)$"; } ]; open-on-workspace = wsName."9"; } # gaming
        # Chromium/helium auxiliary popups float instead of wrecking the layout
        # (niri has no cross-workspace pin — accepted loss vs Hyprland's `pin`).
        # Video PiP: class is empty, title "Picture in picture" (spaces) — the
        # char-classes tolerate both spellings and capitalisation.
        { matches = [ { title = "^([Pp]icture[ -][Ii]n[ -][Pp]icture)$"; } ]; open-floating = true; }
        # Chrome built-in notification → empty app-id AND empty title.
        { matches = [ { app-id = "^$"; title = "^$"; } ]; open-floating = true; }
        # GNOME spacebar quick-preview (Sushi / NautilusPreviewer) → float like
        # macOS Quick Look instead of tiling into the layout.
        { matches = [ { app-id = "^(org.gnome.NautilusPreviewer)$"; } ]; open-floating = true; }
        # Noctalia's own settings window.
        { matches = [ { app-id = "^dev\\.noctalia\\.Noctalia$"; } ]; open-floating = true; }
      ];

      # Noctalia's wallpaper/backdrop layers render inside the overview
      # backdrop (wallpaper stays visible behind the zoomed-out workspaces).
      layer-rules = [
        { matches = [ { namespace = "^noctalia-wallpaper"; } ]; place-within-backdrop = true; }
        { matches = [ { namespace = "^noctalia-backdrop"; } ]; place-within-backdrop = true; }
      ];

      # The Noctalia border fragment owns the *palette* side of layout {}
      # (gaps 8, 2px borders in the live wallpaper colours — rendered from
      # noctalia-templates/niri-border.kdl.tmpl, seeded with the Catppuccin
      # fallback below). Structural layout knobs that never change with the
      # palette live here in the typed settings instead.
      #
      # Windows open at half the working area instead of their own requested
      # width (Spotify/Electron remember a full-bleed size and would swallow
      # the side gaps); Mod+F (maximize-column) gives full width with margins,
      # Mod+R cycles the presets.
      layout.default-column-width.proportion = 0.5;

      environment = {
        # Qt platform theme (qt6ct) so Qt apps follow Noctalia's palette (see
        # the qt6ct notes in mixins/qt.nix); QS_ICON_THEME is the Quickshell-
        # specific icon override kept for Qt tooling.
        QS_ICON_THEME = "Colloid-Dark";
        QT_QPA_PLATFORMTHEME = "qt6ct";
        # NVIDIA + Wayland hint (explicit-sync is automatic on recent drivers).
        "__GL_GSYNC_ALLOWED" = "1";
        # iGPU pins, formerly computed per-login by uwsm/env-hyprland: the
        # session is iGPU-primary always (niri's default renderer), so these
        # are static now. VA-API on the iGPU; Mesa-only EGL + Intel-only
        # Vulkan ICD keep Chromium/Electron (and any GL/Vulkan client) from
        # opening the nvidia render node and pinning it at D0. Offloaded apps
        # (pkgs.nvidiaOffloadEnv) re-expand the vendor list themselves.
        LIBVA_DRIVER_NAME = "iHD";
        "__EGL_VENDOR_LIBRARY_FILENAMES" = "/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json";
        VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
        VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
      };

      # Cursor for native Wayland + XWayland (niri exports XCURSOR_THEME/SIZE
      # from this block); keep in sync with home.pointerCursor below.
      cursor = {
        theme = "Bibata-Modern-Classic";
        size = 24;
      };

      prefer-no-csd = true;
      hotkey-overlay.skip-at-startup = true;
    };

    # niri-flake has no typed options for `recent-windows` (niri ≥25.11) or
    # `include` (≥26.04) — append them as raw KDL after the rendered settings.
    # options.…config.default is the untouched settings render (recursion-free;
    # referencing config.programs.niri.finalConfig here would recurse, since
    # finalConfig serializes the very `config` value being defined). Validation
    # still runs `niri validate` on the combined result at build time.
    config =
      inputs.niri.lib.kdl.serialize.nodes options.programs.niri.config.default
      + ''

        // Runtime-mutable fragments (the niri equivalent of `hyprctl eval`):
        // power-tune owns the eDP-1 output block (240↔60Hz refresh flip);
        // Noctalia owns the layout block (wallpaper-derived border colours,
        // re-rendered on every palette change, config reloaded via post_hook).
        // optional=true: a missing fragment logs a warning instead of failing.
        include optional=true "~/.cache/power-tune/edp-refresh.kdl"
        include optional=true "~/.cache/noctalia/niri-border.kdl"

        // Native MRU Alt-Tab switcher (replaces the old Quickshell alttab).
        // Hold Alt: Tab cycles forward, Shift+Tab back; release commits,
        // Escape cancels. An explicit binds{} replaces ALL default binds, so
        // Mod+Tab stays free for focus-workspace-previous above. Alt+grave
        // cycles windows of the same app (macOS Cmd+`).
        recent-windows {
            binds {
                Alt+Tab       { next-window; }
                Alt+Shift+Tab { previous-window; }
                Alt+grave     { next-window filter="app-id"; }
            }
        }
      '';
  };

  # Seed the runtime fragments so first login (before Noctalia's first render /
  # power-tune's first flip) has sane defaults: 240Hz, and the same static
  # Catppuccin Mocha border fallback the Hyprland config carried (mauve active
  # / surface2 inactive). Copied (not symlinked) only-if-absent: both files are
  # runtime-owned after this — power-tune rewrites the first, Noctalia
  # re-renders the second.
  home.activation.seedNiriFragments =
    let
      refreshSeed = pkgs.writeText "edp-refresh-seed.kdl" ''
        output "eDP-1" {
            mode "2560x1600@240"
            scale 1.25
            position x=2560 y=0
        }
      '';
      borderSeed = pkgs.writeText "niri-border-seed.kdl" ''
        layout {
            gaps 8
            background-color "transparent"
            focus-ring {
                off
            }
            border {
                on
                width 2
                active-color "#cba6f7"
                inactive-color "#585b70"
            }
        }
      '';
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "$HOME/.cache/power-tune/edp-refresh.kdl" ]; then
        run mkdir -p "$HOME/.cache/power-tune"
        run cp --no-preserve=mode ${refreshSeed} "$HOME/.cache/power-tune/edp-refresh.kdl"
      fi
      if [ ! -e "$HOME/.cache/noctalia/niri-border.kdl" ]; then
        run mkdir -p "$HOME/.cache/noctalia"
        run cp --no-preserve=mode ${borderSeed} "$HOME/.cache/noctalia/niri-border.kdl"
      fi
    '';

  # Power automation (see powerTune in the let block): refresh rate, keyboard
  # aura and the relog prompt all follow AC/battery. Bound to
  # graphical-session.target so it starts and stops with the niri session and
  # inherits NIRI_SOCKET (niri-session imports its environment into the systemd
  # user manager) — niri msg needs it.
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

  # GUI polkit auth agent (generic Qt agent; replaces hyprpolkitagent, which
  # was the last thing launched from a compositor-start hook — everything
  # session-scoped is a plain user service now).
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

  # Compositor-essential session packages. The generic GNOME/desktop apps and
  # their MIME defaults live in users/kyandesutter/mixins/desktop-apps.nix.
  #   • wl-clip-persist: keeps the regular Wayland selection alive after the
  #     source app exits so noctalia's clipboard poller can capture it (launched
  #     from autostart.nix).
  home.packages = with pkgs; [
    wl-clip-persist

    # GTK theme noctalia's gtk template sets via gsettings/dconf (adw-gtk3-dark).
    # Installed here so that theme name resolves; noctalia, not the gtk module,
    # selects it (see the dark-mode block below).
    adw-gtk3

    # Icon themes. Colloid-Dark is the desktop-wide icon set (set via gtk.iconTheme
    # below, plus qt{5,6}ct.conf + QS_ICON_THEME above for Qt). adwaita is kept
    # as the complete freedesktop fallback so any icon Colloid lacks resolves
    # to a real glyph instead of the broken-image placeholder.
    colloid-icon-theme
    adwaita-icon-theme

    # Qt platform theme engines. QT_QPA_PLATFORMTHEME=qt6ct (environment above)
    # points Qt6 apps at qt6ct; qt5ct themes Qt5 apps. Both read Noctalia's
    # generated colour scheme via the qt{6,5}ct.conf written in mixins/qt.nix.
    kdePackages.qt6ct
    libsForQt5.qt5ct
  ];

  # Cursor theme — Bibata Modern Classic, the black variant. Sets it for GTK
  # and X11/XWayland (x11.enable exports XCURSOR_THEME/SIZE); native Wayland
  # reads it from settings.cursor above.
  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # Dark mode for GTK / X11 / browsers.
  #
  # noctalia owns app theming (see programs.noctalia.settings.theme.templates
  # in ../mixins/noctalia.nix). Its gtk3/gtk4 templates write the palette to
  # ~/.config/gtk-{3,4}.0/noctalia.css (imported via gtk.css) and their
  # apply.sh post-hook drives the *runtime* dark signal — `gsettings set
  # org.gnome.desktop.interface color-scheme prefer-dark` + `gtk-theme
  # adw-gtk3-dark` (also written to dconf). xdg-desktop-portal reports that to
  # native-Wayland libadwaita/GTK4 apps. So we don't pin the theme *name*
  # here — noctalia chooses it, and pinning our own would drift.
  #
  # We keep this module for the things noctalia does NOT do:
  #   • gtk.iconTheme — sets Colloid-Dark as the icon theme. Noctalia never
  #     touches the icon theme; without this GTK falls back to hicolor and
  #     renders every app/mime icon as the broken-image placeholder.
  #   • gtk-application-prefer-dark-theme in settings.ini — the X11/XWayland
  #     fallback (no xsettingsd here). noctalia's apply.sh only touches
  #     gtk.css + gsettings/dconf, never settings.ini.
  #   • gtk{3,4}.extraCss — own gtk.css declaratively so it holds ONLY the
  #     noctalia import. Noctalia writes noctalia.css but never gtk.css, so an
  #     unmanaged gtk.css silently accumulates cruft: stale @define-color blocks
  #     from old theming tools end up ABOVE the import, and GTK requires @import
  #     before any other rule — so it drops the import, noctalia.css never loads,
  #     and GTK3 apps (Helium via "Use GTK") render un-themed adw-gtk3-dark.
  #     Managing the file keeps the import valid and first. (GTK4/libadwaita read
  #     the accent from the portal, so they were unaffected either way.)
  gtk = {
    enable = true;
    iconTheme = {
      name = "Colloid-Dark";
      package = pkgs.colloid-icon-theme;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk3.extraCss = ''@import url("noctalia.css");'';
    gtk4.extraCss = ''@import url("noctalia.css");'';
  };
}
