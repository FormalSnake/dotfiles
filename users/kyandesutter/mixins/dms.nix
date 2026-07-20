{ config, lib, pkgs, inputs, ... }:
let
  # The single keyboard-aura setter: paint the Aura keyboard to a given accent and
  # apply the effect/brightness appropriate to the current power source. Shared by
  # two triggers — the matugen aura template runs it as a post_hook on every
  # palette change (session start, wallpaper pick, light/dark flip, passing the
  # new accent), and power-tune (niri.nix) calls it on every power-source change
  # (passing the cached accent). Having one setter means the two triggers can't
  # disagree.
  #
  # By power source (see modules/nixos/mixins/power.nix `power-source`):
  #   ac        — static themed colour, full brightness.
  #   powerbank — slow breathe of the themed accent (a "charging" vibe) while still
  #               being treated as battery for power; full brightness.
  #   battery   — themed colour staged but brightness dropped to dark (so a later
  #               AC/relog brings the colour back). This is also the fix for the
  #               LEDs lighting up after a relog on battery: setting an Aura effect
  #               re-enables the backlight, so we re-assert the dark level here.
  # Runs inside DMS's systemd *user* service (limited PATH), so power-source is
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

  # Seed for ~/.config/DankMaterialShell/settings.json (activation block below):
  # disables every idle monitor DMS's IdleService.qml drives — screen-off, lock,
  # and suspend, on both AC and battery. Same reason noctalia's idle was
  # force-disabled: the internal panel (eDP-1) fails its wake modeset with
  # `PHY A failed to request refclk` (see systems/g815/default.nix), and that
  # modeset only happens coming back from a DPMS-off, so never blanking on idle
  # dodges it. Manual lock/suspend (SUPER+SHIFT+Escape) is unaffected.
  #
  # Key names verified against upstream quickshell/Common/settings/SettingsSpec.js
  # (AvengeMedia/DankMaterialShell@74896fb): DMS already defaults every one of
  # these to 0 (= disabled), but they're pinned explicitly here rather than
  # relying on that staying true across DMS updates.
  idleSettingsSeed = pkgs.writeText "dms-settings-idle-seed.json" (
    builtins.toJSON {
      acMonitorTimeout = 0;
      acLockTimeout = 0;
      acSuspendTimeout = 0;
      batteryMonitorTimeout = 0;
      batteryLockTimeout = 0;
      batterySuspendTimeout = 0;
    }
  );
in
{
  # Official DankMaterialShell flake home-manager module. DMS is a Quickshell/QML
  # desktop shell. The module installs the `dms-shell` package + runs it as a user
  # systemd service bound to the Wayland systemd target (auto-starts once niri
  # reaches that target).
  imports = [ inputs.dank-material-shell.homeModules.dank-material-shell ];

  # Expose aura-repaint on PATH so power-tune (niri.nix) can call it as the
  # shared keyboard-aura setter (the matugen aura template's post_hook also uses
  # it, by store path).
  home.packages = [ auraRepaint ];

  programs.dank-material-shell = {
    enable = true;
    systemd.enable = true; # user service, PartOf the Wayland/graphical-session target
    enableDynamicTheming = true; # pulls in the deps DMS's own theming needs
  };

  # App theming beyond DMS's builtin templates (gtk3/gtk4, qt5ct/qt6ct, ghostty,
  # …, all unconditionally detected + rendered by DMS itself — see
  # AvengeMedia/DankMaterialShell core/internal/matugen/matugen.go
  # templateRegistry). These `user` templates push the same live wallpaper
  # palette into apps DMS can't theme natively. Sources are installed to
  # ~/.config/matugen/templates/ below; `.default` colour tokens track the
  # active mode, so each output is rewritten on every mode flip / wallpaper
  # change DMS runs matugen for. post_hook strings are themselves rendered
  # through the engine (colour tokens interpolated) before running.
  xdg.configFile = {
    "matugen/templates/aura.tmpl".source = ../matugen-templates/aura.tmpl;
    "matugen/templates/ghostty.tmpl".source = ../matugen-templates/ghostty.tmpl;
    "matugen/templates/neovim.lua.tmpl".source = ../matugen-templates/neovim.lua.tmpl;
    "matugen/templates/equibop.css.tmpl".source = ../matugen-templates/equibop.css.tmpl;
    "matugen/templates/spicetify.ini.tmpl".source = ../matugen-templates/spicetify.ini.tmpl;
    "matugen/templates/obsidian.css.tmpl".source = ../matugen-templates/obsidian.css.tmpl;
    "matugen/templates/niri-border.kdl.tmpl".source = ../matugen-templates/niri-border.kdl.tmpl;
    "matugen/templates/btop.theme.tmpl".source = ../matugen-templates/btop.theme.tmpl;
    "matugen/templates/yazi-flavor.toml.tmpl".source = ../matugen-templates/yazi-flavor.toml.tmpl;

    # DMS reads ~/.config/matugen/config.toml on every re-theme and splices its
    # [config] and [templates] sections verbatim into the matugen invocation it
    # runs itself (buildMergedConfig in matugen.go) — so this is matugen's own
    # TOML syntax, not a DMS-specific format. A bare `[templates]` header is
    # required before the first `[templates.*]` subtable: DMS's merge locates
    # the literal substring "[templates]", which "[templates.aura]" alone does
    # not contain. `~` in input_path/output_path is expanded by matugen itself.
    "matugen/config.toml".text = ''
      [config]

      [templates]

      # ASUS Aura keyboard. Output file doubles as the "current accent" cache
      # that power-tune (niri.nix) reads to restore today's colour on a
      # power-source change; the post_hook does the actual repaint.
      [templates.aura]
      input_path = "~/.config/matugen/templates/aura.tmpl"
      output_path = "~/.cache/dank/aura-color"
      post_hook = "${auraRepaint}/bin/aura-repaint {{colors.primary.default.hex_stripped}}"

      # Ghostty: written into ghostty's themes dir; config references it with
      # `theme = "Matugen"` (see mixins/ghostty.nix). SIGUSR2 live-reloads it
      # (ghostty >= 1.2) without a restart. DMS's own builtin ghostty template
      # writes a separate `themes/dankcolors` file we don't reference, so the
      # two don't conflict.
      [templates.ghostty]
      input_path = "~/.config/matugen/templates/ghostty.tmpl"
      output_path = "~/.config/ghostty/themes/Matugen"
      post_hook = "pkill -SIGUSR2 ghostty || true"

      # Neovim: base16 lua module consumed by dynamic-base16.nvim (watch =
      # true) — no hook needed, the plugin watches the file. See neovim.nix.
      [templates.neovim]
      input_path = "~/.config/matugen/templates/neovim.lua.tmpl"
      output_path = "~/.config/nvim/lua/dank_base16.lua"

      # Equibop (Discord): Equicord hot-reloads the themes folder, so no hook.
      # One-time: enable the theme in Equibop -> Settings -> Themes.
      [templates.equibop]
      input_path = "~/.config/matugen/templates/equibop.css.tmpl"
      output_path = "~/.config/equibop/themes/dank.theme.css"

      # Spotify via spicetify. Writes the Comfy theme's color.ini, then
      # re-applies it to the (Flatpak) Spotify — see mixins/spicetify.nix.
      # Absolute spicetify path: this hook runs inside DMS's systemd user
      # service, whose PATH won't include the home profile bin. If the UI
      # doesn't visibly recolour, Ctrl+Shift+R inside Spotify forces it.
      #
      # The config dir is selected via the SPICETIFY_CONFIG env var, NOT a
      # `-c <path>` flag: in spicetify-cli v2 `-c`/`--config` is a standalone,
      # non-chainable flag that just prints the config path and exits, so
      # `spicetify -c <path> apply` silently runs nothing (exit 0) and Spotify
      # never gets re-patched. Setting SPICETIFY_CONFIG points apply at this
      # config dir explicitly (the systemd service may not have XDG_CONFIG_HOME).
      [templates.spicetify]
      input_path = "~/.config/matugen/templates/spicetify.ini.tmpl"
      output_path = "~/.config/spicetify/Themes/Comfy/color.ini"
      post_hook = "SPICETIFY_CONFIG=${config.home.homeDirectory}/.config/spicetify ${pkgs.spicetify-cli}/bin/spicetify apply --no-restart || true"

      # Obsidian (Minimal theme). Rendered into the vault's snippet dir;
      # Obsidian watches ~/Notes/.obsidian/snippets and hot-reloads on write,
      # so no post_hook. macOS rides Minimal's built-in Flexoki preset instead
      # — no DMS there — so this template is Linux-only (dms.nix is
      # g815-only). scripts/obsidian-vault-bootstrap.sh seeds an empty enabled
      # snippet before the first render.
      [templates.obsidian]
      input_path = "~/.config/matugen/templates/obsidian.css.tmpl"
      output_path = "~/Notes/.obsidian/snippets/dank.css"

      # niri window borders. DMS doesn't touch the compositor; this renders the
      # wallpaper palette into the layout fragment niri's config.kdl includes
      # (include optional=true, placed LAST so it overrides the rendered
      # defaults — see mixins/niri.nix), and the post_hook reloads niri's
      # config so the colours apply instantly. mixins/niri.nix seeds a Flexoki
      # fallback copy for the first login before the first render here.
      # primary = active border; error = urgent; outline = inactive.
      [templates.niri-border]
      input_path = "~/.config/matugen/templates/niri-border.kdl.tmpl"
      output_path = "~/.cache/dank/niri-border.kdl"
      post_hook = "${pkgs.niri}/bin/niri msg action load-config-file || true"

      # btop. DMS has no builtin btop template; programs.btop.settings.color_theme
      # in programs.nix points at this output. Picks up colours on next launch
      # (no live reload).
      [templates.btop]
      input_path = "~/.config/matugen/templates/btop.theme.tmpl"
      output_path = "~/.config/btop/themes/dank.theme"

      # yazi. DMS has no builtin yazi template; programs.yazi.theme in
      # programs.nix points ~/.config/yazi/theme.toml's [flavor] dark/light at
      # "dank", so this one output covers both modes. Picks up colours on next
      # yazi launch (no live reload).
      [templates.yazi]
      input_path = "~/.config/matugen/templates/yazi-flavor.toml.tmpl"
      output_path = "~/.config/yazi/flavors/dank.yazi/flavor.toml"
    '';
  };

  # settings.json is DMS's own runtime-mutable config (rewritten by the Settings
  # UI and by DMS itself on every save), so home-manager must not own the whole
  # file — seed it once, only if absent, so idle stays disabled from the very
  # first session rather than however long it takes to open Settings manually.
  home.activation.dmsIdleSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.config/DankMaterialShell/settings.json" ]; then
      run mkdir -p "$HOME/.config/DankMaterialShell"
      run cp --no-preserve=mode ${idleSettingsSeed} "$HOME/.config/DankMaterialShell/settings.json"
    fi
  '';
}
