{ config, inputs, pkgs, ... }:
let
  # The single keyboard-aura setter: paint the Aura keyboard to a given accent and
  # apply the effect/brightness appropriate to the current power source. Shared by
  # two triggers — noctalia runs it as a post_hook on every palette change (session
  # start, wallpaper pick, light/dark flip, passing the new accent), and power-tune
  # (hyprland.nix) calls it on every power-source change (passing the cached accent).
  # Having one setter means the two triggers can't disagree.
  #
  # By power source (see modules/nixos/mixins/asus.nix `power-source`):
  #   ac        — static themed colour, full brightness.
  #   powerbank — slow breathe of the themed accent (a "charging" vibe) while still
  #               being treated as battery for power; full brightness.
  #   battery   — themed colour staged but brightness dropped to dark (so a later
  #               AC/relog brings the colour back). This is also the fix for the
  #               LEDs lighting up after a relog on battery: setting an Aura effect
  #               re-enables the backlight, so we re-assert the dark level here.
  # Runs inside noctalia's systemd *user* service (limited PATH), so power-source is
  # pinned by absolute path; brightness is driven through asusd (asusctl leds) since
  # the user can't write the root-owned /sys LED node directly.
  auraRepaint = pkgs.writeShellApplication {
    name = "aura-repaint";
    runtimeInputs = [
      pkgs.asusctl
      pkgs.coreutils
    ];
    text = ''
      colour="''${1:?usage: aura-repaint <hex>}"
      case "$(/run/current-system/sw/bin/power-source 2>/dev/null || echo ac)" in
        ac)
          asusctl aura effect static -c "$colour" || true
          asusctl leds set high || true
          ;;
        powerbank)
          asusctl aura effect breathe --colour "$colour" --colour2 000000 --speed med || true
          asusctl leds set high || true
          ;;
        *)
          asusctl aura effect static -c "$colour" || true
          asusctl leds set off || true
          ;;
      esac
    '';
  };

  # Per-wallpaper scheme override. Noctalia's colour source is a single global
  # setting (wallpaper-derived matugen vs a hardcoded custom palette), so to make
  # *some* wallpapers pin a fixed palette while everything else stays matugen, we
  # flip the source at runtime on each wallpaper change. Noctalia fires the
  # `wallpaper_changed` hook with the newly-picked image in $NOCTALIA_WALLPAPER_PATH
  # (see noctalia-shell src/app/application_services.cpp); if that path contains
  # "flexoki" (any case) we snap the whole shell to the hardcoded Flexoki palette
  # below via `noctalia msg color-scheme-set custom Flexoki`, otherwise we return
  # to the wallpaper-derived M3 palette (`color-scheme-set wallpaper m3-tonal-spot`,
  # matching theme.wallpaper_scheme). This runs inside noctalia's systemd *user*
  # service (limited PATH), so the noctalia binary is provided via runtimeInputs.
  # `color-scheme-set` fires colors_changed (NOT wallpaper_changed), so no loop.
  flexokiScheme = pkgs.writeShellApplication {
    name = "flexoki-scheme";
    runtimeInputs = [ config.programs.noctalia.package ];
    text = ''
      path="''${NOCTALIA_WALLPAPER_PATH:-}"
      shopt -s nocasematch
      if [[ "$path" == *flexoki* ]]; then
        noctalia msg color-scheme-set custom Flexoki
      else
        noctalia msg color-scheme-set wallpaper m3-tonal-spot
      fi
    '';
  };
in
{
  # Official noctalia flake home-manager module. noctalia V5 is a native C++ /
  # OpenGL ES Wayland shell (the V4 line was Quickshell). The module installs the
  # `noctalia` shell + runs it as a user systemd service bound to the Wayland
  # systemd target (auto-starts once Hyprland/uwsm reaches that target).
  imports = [ inputs.noctalia.homeModules.default ];

  # Expose aura-repaint on PATH so power-tune (hyprland.nix) can call it as the
  # shared keyboard-aura setter (the noctalia post_hook below uses it by store path).
  home.packages = [ auraRepaint ];

  programs.noctalia = {
    enable = true;
    systemd.enable = true; # user service, PartOf the Wayland/graphical-session target

    # Hardcoded Flexoki palette (kepano's "inky" scheme), rendered by the module to
    # ~/.config/noctalia/palettes/Flexoki.json. This is NOT matugen — it's the real
    # Flexoki hex values, activated only when a Flexoki-named wallpaper is picked
    # (flexokiScheme runs `color-scheme-set custom Flexoki`; all other wallpapers
    # stay wallpaper-derived). Both variants are defined so the SUPER+SHIFT+T
    # light/dark toggle keeps working while Flexoki is active. Values are the
    # canonical Flexoki palette (kepano/flexoki css/flexoki.css): dark uses the
    # -400 accents on black (#100F0F) with base-200 text; light uses -600 accents
    # on paper (#FFFCF0). The `terminal` blocks mirror Flexoki's own black-box
    # terminal theme verbatim (incl. its purple-as-ANSI-blue mapping). Schema:
    # noctalia-shell src/theme/cli.cpp + fixed_palette.h.
    customPalettes.Flexoki = {
      dark = {
        mPrimary = "#4385BE"; # blue-400
        mOnPrimary = "#100F0F";
        mSecondary = "#3AA99F"; # cyan-400
        mOnSecondary = "#100F0F";
        mTertiary = "#DA702C"; # orange-400
        mOnTertiary = "#100F0F";
        mError = "#D14D41"; # red-400
        mOnError = "#100F0F";
        mSurface = "#100F0F"; # black
        mOnSurface = "#CECDC3"; # base-200 (tx)
        mSurfaceVariant = "#282726"; # base-900
        mOnSurfaceVariant = "#878580"; # base-500 (tx-2)
        mOutline = "#403E3C"; # base-800
        mShadow = "#000000";
        mHover = "#1C1B1A"; # base-950
        mOnHover = "#CECDC3";
        terminal = {
          background = "#100F0F";
          foreground = "#CECDC3";
          cursor = "#CECDC3";
          cursorText = "#100F0F";
          selectionBg = "#403E3C";
          selectionFg = "#FFFCF0";
          normal = {
            black = "#100F0F";
            red = "#D14D41";
            green = "#879A39";
            yellow = "#D0A215";
            blue = "#8B7EC8";
            magenta = "#CE5D97";
            cyan = "#3AA99F";
            white = "#878580";
          };
          bright = {
            black = "#100F0F";
            red = "#AF3029";
            green = "#66800B";
            yellow = "#AD8301";
            blue = "#5E409D";
            magenta = "#A02F6F";
            cyan = "#24837B";
            white = "#6F6E69";
          };
        };
      };
      light = {
        mPrimary = "#205EA6"; # blue-600
        mOnPrimary = "#FFFCF0";
        mSecondary = "#24837B"; # cyan-600
        mOnSecondary = "#FFFCF0";
        mTertiary = "#BC5215"; # orange-600
        mOnTertiary = "#FFFCF0";
        mError = "#AF3029"; # red-600
        mOnError = "#FFFCF0";
        mSurface = "#FFFCF0"; # paper
        mOnSurface = "#100F0F"; # black (tx)
        mSurfaceVariant = "#E6E4D9"; # base-100
        mOnSurfaceVariant = "#6F6E69"; # base-600 (tx-2)
        mOutline = "#DAD8CE"; # base-150
        mShadow = "#000000";
        mHover = "#F2F0E5"; # base-50
        mOnHover = "#100F0F";
        terminal = {
          background = "#FFFCF0";
          foreground = "#100F0F";
          cursor = "#100F0F";
          cursorText = "#FFFCF0";
          selectionBg = "#CECDC3";
          selectionFg = "#100F0F";
          normal = {
            black = "#100F0F";
            red = "#AF3029";
            green = "#66800B";
            yellow = "#AD8301";
            blue = "#5E409D";
            magenta = "#A02F6F";
            cyan = "#24837B";
            white = "#6F6E69";
          };
          bright = {
            black = "#100F0F";
            red = "#D14D41";
            green = "#879A39";
            yellow = "#D0A215";
            blue = "#8B7EC8";
            magenta = "#CE5D97";
            cyan = "#3AA99F";
            white = "#878580";
          };
        };
      };
    };

    # Declarative config written to ~/.config/noctalia/config.toml (the module
    # converts this attrset to TOML and runs `noctalia config validate` on it at
    # build time, so unknown/invalid keys fail the build — keys below all come
    # from the upstream example.toml). noctalia may still mutate this file at
    # runtime via its Settings menu; the service is restart-triggered on changes.
    settings = {
      shell = {
        # UI text font (Pango family). Mirrors caelestia's Geist UI font. noctalia
        # draws its own glyphs/icons from a bundled icon font, so no separate Nerd
        # Font is needed here. There is no distinct monospace key in the schema.
        font_family = "Geist";

        # Opaque panels — mirrors caelestia's appearance.transparency.enabled =
        # false. "solid" is also noctalia's default; set explicitly for clarity.
        panel.transparency_mode = "solid";

        # Session/power menu buttons (the `session` bar widget; SUPER+SHIFT+Escape
        # is bound to lock-and-suspend directly — see hyprland.nix). This list
        # REPLACES noctalia's default action set wholesale (default is lock,
        # logout, lock_and_suspend, reboot, shutdown), so it's the full menu in
        # order; `shortcut` is the in-menu number key. Changes vs default:
        #   • plain `lock` dropped — only lock-and-suspend is used here.
        #   • a "Windows" command button: starts reboot-to-windows.service, which
        #     sets a one-shot UEFI BootNext into Windows and reboots, leaving the
        #     standing default (Limine → latest NixOS) untouched. (Limine, unlike
        #     systemd-boot, has no LoaderEntryOneShot, hence the BootNext route.)
        #   • a "BIOS" command button: `systemctl reboot --firmware-setup`, a
        #     one-shot reboot straight into the UEFI firmware setup.
        #     Both `command`s run from noctalia's user service (limited PATH), so
        #     systemctl is pinned by absolute path; their password prompts are
        #     waived by the polkit rules in modules/nixos/mixins/boot.nix.
        #     `brand-windows`/`cpu` are bundled tabler glyphs. Windows + BIOS sit
        #     just before shutdown at the end of the menu.
        #
        # GOTCHA (noctalia 5.0.0): for a command button the action MUST be
        # `"command"`, NOT `"custom"`. The Settings GUI labels it "Custom" and the
        # config schema accepts any string (it does NOT enum-check `action` — even a
        # bogus value passes `noctalia config validate`), but the session-PANEL
        # renderer only draws `action = "command"`; anything else it logs as
        # `[session] session panel: skipping unknown action "<x>"` and the button
        # silently vanishes. A `command` entry with an empty `command` is likewise
        # skipped.
        # action ∈ lock|logout|lock_and_suspend|suspend|reboot|shutdown|command;
        # variant ∈ default|primary|secondary|outline|ghost|destructive.
        session.actions = [
          {
            action = "lock_and_suspend";
            shortcut = "1";
          }
          {
            action = "logout";
            shortcut = "2";
          }
          {
            action = "reboot";
            shortcut = "3";
          }
          {
            action = "command";
            label = "Windows";
            glyph = "brand-windows";
            command = "/run/current-system/sw/bin/systemctl start reboot-to-windows.service";
            variant = "secondary";
            shortcut = "4";
          }
          {
            action = "command";
            label = "BIOS";
            glyph = "cpu";
            command = "/run/current-system/sw/bin/systemctl reboot --firmware-setup";
            variant = "secondary";
            shortcut = "5";
          }
          {
            action = "shutdown";
            variant = "destructive";
            shortcut = "6";
          }
        ];
      };

      # Bar: caelestia-style full-width, edge-to-edge, solid. The real keys (per
      # the BarConfig struct — example.toml's margin_h/margin_v are stale and
      # silently ignored) are:
      #   margin_ends → inset from each END of the bar along its main axis; 0 =
      #                 spans the full screen width.
      #   margin_edge → distance from the nearest screen edge; >0 floats the bar,
      #                 0 = flush against the top.
      # The bar itself stays a squared solid rectangle (top corners = 0); instead
      # the *desktop* gets the rounded border:
      #
      #   radius_bottom_{left,right} < 0 → concave corners on the bar's inner
      #   (bottom) edge. noctalia renders these as a concave spike that curves
      #   outward into the desktop, so the content area below the bar reads as
      #   having rounded top corners flowing out from under the bar — not the bar
      #   being rounded. Range is -500..500; -20 ≈ a soft notch.
      #
      # A little more padding / widget spacing for breathing room. reserve_space
      # stays true (default) so tiled windows don't underlap it.
      bar.main = {
        margin_ends = 0; # full width
        margin_edge = 0; # flush to the top edge
        radius = 0; # seeds all four corners; top stays squared
        radius_bottom_left = -20; # concave → curves out into the desktop
        radius_bottom_right = -20;
        padding = 16;
        widget_spacing = 12;

        # Widget layout. start/center/end are arrays of widget id strings;
        # overriding a list replaces noctalia's default wholesale (see
        # docs/noctalia-hm-internals.md → "Bar widgets"). Built-in ids imply
        # their type; `spacer_2` is a *named* spacer instance, defined in the
        # top-level `widget.spacer_2` table below.
        start = [ "session" "launcher" "wallpaper" "workspaces" ];
        center = [ "control-center" "media" "audio-visualizer" ];
        end = [
          "tray"
          "spacer_2"
          "notifications"
          "clipboard"
          "network"
          "bluetooth"
          "volume"
          "brightness"
          "battery"
          "clock"
        ];
      };

      # Named spacer instance referenced from bar.main.end. A non-builtin id, so
      # its type must be declared explicitly (defaults otherwise).
      widget.spacer_2.type = "spacer";

      # Dynamic, wallpaper-derived palette is now the single source of truth for
      # the desktop's colours (replacing the static Catppuccin builtin). On every
      # wallpaper pick or light/dark flip, Noctalia regenerates a Material Design 3
      # palette from the image, re-renders all templates below, and runs their
      # hooks. `wallpaper_scheme` selects the M3 generator (tonal-spot = balanced /
      # legible; "vibrant" for punchier accents). Mode defaults to dark; the
      # SUPER+SHIFT+T keybind (../mixins/hyprland.nix) toggles light/dark via
      # `noctalia msg theme-mode-toggle`. See docs/superpowers/specs/
      # 2026-06-19-noctalia-dynamic-theming-design.md.
      theme = {
        mode = "dark";
        source = "wallpaper";
        wallpaper_scheme = "m3-tonal-spot";

        # App theming. The builtin gtk3/gtk4 templates render the live palette into
        # ~/.config/gtk-{3,4}.0/noctalia.css (imported via gtk.css) and drive the
        # dconf/gsettings dark signal at runtime — this is what makes native GTK/Qt
        # and X11 apps follow the palette, and is also what lets Helium follow it
        # for free via its "Use GTK theme" appearance setting. adw-gtk3 is installed
        # by the gtk module in ../mixins/hyprland.nix.
        #
        # The `user` templates push the same live palette into apps Noctalia can't
        # theme natively. `.default` colour tokens track the active mode, so each
        # output is rewritten on every mode flip / wallpaper change. Template
        # sources are installed to ~/.config/noctalia/templates/ via xdg.configFile
        # below. post_hook strings are themselves rendered through the engine
        # (colour tokens interpolated) before running.
        templates = {
          enable_builtin_templates = true;
          # gtk3/gtk4 theme GTK apps; qt writes qt5ct/qt6ct colour schemes that the
          # Qt platform theme (QT_QPA_PLATFORMTHEME=qt6ct, set in hyprland.nix)
          # reads. Qt/GTK apps follow the palette at launch (no live recolour — the
          # toolkits don't hot-reload palettes).
          builtin_ids = [ "gtk3" "gtk4" "qt" "btop" ];

          # Community templates (downloaded from api.noctalia.dev, cached locally,
          # rendered on each palette change):
          #   yazi  → writes ~/.config/yazi/flavors/noctalia.yazi/flavor.toml and
          #           its apply.sh auto-points ~/.config/yazi/theme.toml at it
          #           ([flavor] dark/light = "noctalia"). yazi is removed from the
          #           catppuccin static list (mixins/catppuccin.nix). Picks up on
          #           next yazi launch.
          #   steam → writes a Matugen colour file into the Millennium "Material-
          #           Theme" skin (~/.steam/.../skins/Material-Theme/.../matugen.css).
          #           Millennium itself is now nix-managed (programs.steam.package =
          #           millennium-steam, see modules/nixos/mixins/gaming.nix). One-time
          #           manual setup remains (runtime, GUI): in Millennium install the
          #           Material-Theme skin (ID ipYjqODds05KMcvh7QJn), pick the
          #           "Matugen" colour variant, restart Steam. Harmless no-op until
          #           then.
          enable_community_templates = true;
          community_ids = [ "yazi" "steam" ];

          user = {
            # ASUS Aura keyboard. Output file doubles as the "current accent" cache
            # that asus.nix's aura-repaint reads to restore today's colour; the
            # post_hook does the actual repaint. NOTE: in light mode `primary` can
            # be pale — switch to a saturated role (e.g. tertiary) or add a
            # `saturate` filter here if the keyboard reads washed out.
            aura = {
              enabled = true;
              input_path = "~/.config/noctalia/templates/aura.tmpl";
              output_path = "~/.cache/noctalia/aura-color";
              post_hook = "${auraRepaint}/bin/aura-repaint {{ colors.primary.default.hex_stripped }}";
            };

            # Ghostty: written into ghostty's themes dir; config references it with
            # `theme = "Matugen"` (see ghostty.nix). SIGUSR2 live-reloads it
            # (ghostty >= 1.2) without a restart.
            ghostty = {
              enabled = true;
              input_path = "~/.config/noctalia/templates/ghostty.tmpl";
              output_path = "~/.config/ghostty/themes/Matugen";
              post_hook = "pkill -SIGUSR2 ghostty || true";
            };

            # Neovim: base16 lua module consumed by dynamic-base16.nvim
            # (watch = true) — no hook needed, the plugin watches the file. See
            # neovim.nix.
            neovim = {
              enabled = true;
              input_path = "~/.config/noctalia/templates/neovim.lua.tmpl";
              output_path = "~/.config/nvim/lua/noctalia_base16.lua";
            };

            # Equibop (Discord): Equicord hot-reloads the themes folder, so no hook.
            # One-time: enable the theme in Equibop -> Settings -> Themes.
            equibop = {
              enabled = true;
              input_path = "~/.config/noctalia/templates/equibop.css.tmpl";
              output_path = "~/.config/equibop/themes/noctalia.theme.css";
            };

            # Spotify via spicetify. Writes the Comfy theme's color.ini, then
            # re-applies it to the (Flatpak) Spotify — see mixins/spicetify.nix and
            # the spec §5 for the one-time setup + the per-update maintenance tax.
            # Absolute spicetify path: this hook runs inside noctalia's systemd
            # user service, whose PATH won't include the home profile bin. If the
            # UI doesn't visibly recolour, Ctrl+Shift+R inside Spotify forces it.
            #
            # The config dir is selected via the SPICETIFY_CONFIG env var, NOT a
            # `-c <path>` flag: in spicetify-cli v2 `-c`/`--config` is a standalone,
            # non-chainable flag that just prints the config path and exits, so
            # `spicetify -c <path> apply` silently runs nothing (exit 0) and Spotify
            # never gets re-patched. Setting SPICETIFY_CONFIG points apply at this
            # config dir explicitly (the systemd service may not have XDG_CONFIG_HOME).
            spicetify = {
              enabled = true;
              input_path = "~/.config/noctalia/templates/spicetify.ini.tmpl";
              output_path = "~/.config/spicetify/Themes/Comfy/color.ini";
              post_hook = "SPICETIFY_CONFIG=${config.home.homeDirectory}/.config/spicetify ${pkgs.spicetify-cli}/bin/spicetify apply --no-restart || true";
            };

            # Hyprland borders + group/groupbar colours. Noctalia doesn't touch the
            # compositor. This replicates the exact property set its built-in
            # `hyprland` template applies (general.col.{active,inactive}_border,
            # group.col.border_*, group.groupbar.col.*), but pushes it live with
            # `hyprctl eval 'hl.config{…}'`. We hand-roll it because this is Hyprland
            # 0.55+ Lua config (see docs/hyprland-lua.md): the built-in template's
            # apply.sh appends `require("noctalia")` to ~/.config/hypr/hyprland.lua,
            # but that's a read-only home-manager symlink here, and the built-in
            # doesn't re-apply live. `hyprctl eval` does both — instant, no flicker —
            # and Noctalia re-runs it on every session start / wallpaper / mode
            # change. primary = active border; secondary = active group; error =
            # locked; surface = inactive.
            hyprland-border = {
              enabled = true;
              input_path = "~/.config/noctalia/templates/hypr-border.tmpl";
              output_path = "~/.cache/noctalia/hypr-border";
              post_hook = ''hyprctl eval 'hl.config({ general = { col = { active_border = "rgb({{ colors.primary.default.hex_stripped }})", inactive_border = "rgb({{ colors.surface.default.hex_stripped }})" } }, group = { col = { border_active = "rgb({{ colors.secondary.default.hex_stripped }})", border_inactive = "rgb({{ colors.surface.default.hex_stripped }})", border_locked_active = "rgb({{ colors.error.default.hex_stripped }})", border_locked_inactive = "rgb({{ colors.surface.default.hex_stripped }})" }, groupbar = { col = { active = "rgb({{ colors.secondary.default.hex_stripped }})", inactive = "rgb({{ colors.surface.default.hex_stripped }})", locked_active = "rgb({{ colors.error.default.hex_stripped }})", locked_inactive = "rgb({{ colors.surface.default.hex_stripped }})" } } } })' '';
            };

            # Alt-Tab switcher (Quickshell). Emits a tiny JSON file of the live
            # palette that the alttab QML watches (Quickshell FileView) and parses
            # at runtime — see mixins/alttab.nix. No post_hook: the QML reloads on
            # file change. When this file is missing/unparseable (e.g. before the
            # first palette render) the QML falls back to baked catppuccin values.
            alttab = {
              enabled = true;
              input_path = "~/.config/noctalia/templates/alttab.json.tmpl";
              output_path = "~/.cache/noctalia/alttab-colors.json";
            };
          };
        };
      };

      # Wallpapers live in a *mutable* set under ~/Pictures/Wallpapers/{light,dark}
      # (owner-managed, intentionally not tracked by the flake — see the design
      # spec). No rotation: automation.enabled = false, so the palette only changes
      # when you pick a wallpaper from Noctalia's picker or flip light/dark. Each
      # mode pulls from its own folder. crop = fill the screen.
      wallpaper = {
        enabled = true;
        fill_mode = "crop";
        directory_dark = "${config.home.homeDirectory}/Pictures/Wallpapers/dark";
        directory_light = "${config.home.homeDirectory}/Pictures/Wallpapers/light";
        automation.enabled = false;
      };

      # Idle screen-off (DPMS) is DISABLED — the laptop stays "caffeinated"; the
      # displays never blank on idle. Off rather than just a long timeout for two
      # reasons:
      #   1. Always-on is the desired behaviour (manual blank still available via
      #      `session lock-and-suspend`, SUPER+SHIFT+Escape).
      #   2. It dodges the i915 "lit but black" internal-panel bug: eDP-1 fails its
      #      wake modeset with `PHY A failed to request refclk` (see
      #      systems/g815/default.nix), and that modeset only happens when the panel
      #      comes back from a DPMS-off. Never blanking it on idle means it never
      #      hits that failing wake path.
      # The Wayland idle-inhibit locks held during games/downloads (see
      # modules/nixos/mixins/{gaming,asus}.nix) are now belt-and-suspenders here.
      idle.behavior."screen-off" = {
        timeout = 660;
        command = "noctalia:dpms-off";
        resume_command = "noctalia:dpms-on";
        enabled = false;
      };

      # Weather, with coordinates resolved automatically from IP geolocation
      # ([location].auto_locate). Shown in the control center / dashboard. Unit
      # stays celsius (noctalia default). [location] is also the single "where am
      # I" source feeding the night light schedule below (sunset/sunrise).
      weather.enabled = true;
      location.auto_locate = true;

      # Display brightness control. enable_ddcutil turns on the DDC/CI backend so
      # the *external* monitor (HDMI-A-1, an ASUS PA278CGV) is driven over i2c by
      # both Noctalia's brightness slider AND the XF86MonBrightness keybinds
      # (which call `noctalia msg brightness-up/down current` — see hyprland.nix).
      # The internal panel (eDP-1, nvidia_wmi_ec_backlight) auto-resolves to the
      # backlight backend; no per-monitor override needed. The i2c stack (group,
      # /dev/i2c-* access, ddcutil) is wired in modules/nixos/mixins/hyprland.nix.
      brightness.enable_ddcutil = true;

      # Night light (colour-temperature warm shift). It has no schedule of its
      # own — it follows [location], so with auto_locate above it only kicks in
      # between the region's real sunset and sunrise. force = false keeps it on
      # that automatic schedule (force = true would pin it on regardless of time).
      nightlight = {
        enabled = true;
        force = false;
        temperature_day = 6500; # neutral during the day (no shift)
        temperature_night = 4000; # warm after sunset
      };

      # OSD popups (volume/brightness/etc). bottom_center mirrors the macOS HUD
      # placement. brightness is on by default; set explicitly so the keybind
      # feedback is guaranteed visible.
      osd = {
        position = "bottom_center";
        kinds.brightness = true;
      };

      # Event hooks: run a command on a shell event. Notifications surface through
      # noctalia's own notification daemon. notify-send is pinned by store path
      # because the noctalia *user* service runs with a limited PATH (same reason
      # aura-repaint uses absolute paths). The $NOCTALIA_* variables are expanded
      # by the shell when the hook fires; `\${...}` escapes Nix's own interpolation
      # so the literal shell variable survives into config.toml.
      hooks = {
        # Low-battery warning (noctalia has none by default). Threshold arms the
        # battery_under_threshold hook below.
        battery_low_percent_threshold = 15;
        battery_under_threshold =
          "${pkgs.libnotify}/bin/notify-send -u critical 'Power' \"Battery at \${NOCTALIA_BATTERY_PERCENT}% — plug in\"";
        power_profile_changed =
          "${pkgs.libnotify}/bin/notify-send 'Power' \"Profile: $NOCTALIA_POWER_PROFILE\"";
        theme_mode_changed =
          "${pkgs.libnotify}/bin/notify-send 'Noctalia' \"Theme: $NOCTALIA_THEME_MODE\"";
        # flexoki-scheme flips the colour source per wallpaper (Flexoki-named
        # wallpapers → hardcoded Flexoki palette, everything else → matugen); see
        # the flexokiScheme note in the let block above.
        wallpaper_changed = "${flexokiScheme}/bin/flexoki-scheme; ${pkgs.libnotify}/bin/notify-send 'Noctalia' 'Wallpaper changed'";
      };
    };
  };

  # Template sources for the user templates declared above. Installed read-only
  # into ~/.config/noctalia/templates/; Noctalia renders them into their
  # output_path on every palette change. These are matugen-syntax templates
  # (Noctalia's engine is matugen-compatible), mapping M3 colour roles into each
  # app's format.
  xdg.configFile = {
    "noctalia/templates/aura.tmpl".source = ../noctalia-templates/aura.tmpl;
    "noctalia/templates/ghostty.tmpl".source = ../noctalia-templates/ghostty.tmpl;
    "noctalia/templates/neovim.lua.tmpl".source = ../noctalia-templates/neovim.lua.tmpl;
    "noctalia/templates/equibop.css.tmpl".source = ../noctalia-templates/equibop.css.tmpl;
    "noctalia/templates/spicetify.ini.tmpl".source = ../noctalia-templates/spicetify.ini.tmpl;
    "noctalia/templates/hypr-border.tmpl".source = ../noctalia-templates/hypr-border.tmpl;
    "noctalia/templates/alttab.json.tmpl".source = ../noctalia-templates/alttab.json.tmpl;
  };
}
