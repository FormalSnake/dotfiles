{ config, lib, pkgs, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;
  p = import ./palette.nix;

  # Render a bat/Sublime tmTheme from a Flexoki base16 view. bat has no upstream
  # Flexoki theme (only an unsupported .sublime-color-scheme), so generate one
  # from the canonical base16 textmate template (chriskempson/base16-textmate),
  # vendored alongside. `themes.<name>` wants an attrset of a theme *folder* plus
  # the file within it, so wrap each rendered theme in a one-file store dir.
  template = builtins.readFile ./base16.tmTheme.mustache;
  strip = lib.removePrefix "#";
  mkTmTheme =
    name: b16:
    builtins.replaceStrings
      [
        "{{scheme-name}}"
        "{{scheme-author}}"
        "{{scheme-slug}}"
        "{{base00-hex}}"
        "{{base01-hex}}"
        "{{base02-hex}}"
        "{{base03-hex}}"
        "{{base04-hex}}"
        "{{base05-hex}}"
        "{{base07-hex}}"
        "{{base08-hex}}"
        "{{base09-hex}}"
        "{{base0A-hex}}"
        "{{base0B-hex}}"
        "{{base0C-hex}}"
        "{{base0D-hex}}"
        "{{base0E-hex}}"
        "{{base0F-hex}}"
      ]
      [
        name
        "Steph Ango"
        name
        (strip b16.base00)
        (strip b16.base01)
        (strip b16.base02)
        (strip b16.base03)
        (strip b16.base04)
        (strip b16.base05)
        (strip b16.base07)
        (strip b16.base08)
        (strip b16.base09)
        (strip b16.base0A)
        (strip b16.base0B)
        (strip b16.base0C)
        (strip b16.base0D)
        (strip b16.base0E)
        (strip b16.base0F)
      ]
      template;

  # Official Flexoki fish themes (github.com/kepano/flexoki/fish). fish persists
  # colours as *universal* variables via `fish_config theme choose`, so the old
  # catppuccin values survive removing that module — re-choosing a flexoki theme
  # every login overwrites them.
  fishDark = pkgs.writeText "Flexoki Dark.theme" ''
    # name: Flexoki Dark
    # url: https://stephango.com/flexoki
    # preferred_background: 100f0f

    fish_color_normal	cecdc3
    fish_color_command	da702c
    fish_color_keyword	879a39
    fish_color_quote	3aa99f
    fish_color_redirection	ce5d97
    fish_color_end		ce5d97
    fish_color_error	d14d41
    fish_color_param	4385be
    fish_color_operator	878580
    fish_color_comment	575653

    fish_pager_color_description b7b5ac
    fish_pager_color_selected_prefix      100f0f
    fish_pager_color_selected_completion  1c1b1a
    fish_pager_color_selected_description 282726
    fish_pager_color_selected_background --background=cecdc3
  '';
  fishLight = pkgs.writeText "Flexoki Light.theme" ''
    # name: Flexoki Light
    # url: https://stephango.com/flexoki
    # preferred_background: fffcf0

    fish_color_normal	100f0f
    fish_color_command	bc5215
    fish_color_keyword	66800b
    fish_color_quote	24837b
    fish_color_redirection	a02f6f
    fish_color_end		a02f6f
    fish_color_error	af3029
    fish_color_param	205ea6
    fish_color_operator	6f6e69
    fish_color_comment	b7b5ac

    fish_pager_color_description b7b5ac
    fish_pager_color_selected_prefix      fffcf0
    fish_pager_color_selected_completion  fcf0e5
    fish_pager_color_selected_description e6e4d9
    fish_pager_color_selected_background --background=100f0f
  '';
in
lib.mkMerge [
  {
    # bat: Flexoki tmThemes generated from the palette. macOS follows the system
    # appearance (`auto:system` reads AppleInterfaceStyle live per-invocation);
    # on Linux that mode is unsupported and silently falls back to bat's builtin
    # dark theme, so pin the dark theme by name (DMS has no bat template —
    # this is the static fallback that replaces catppuccin mocha here).
    programs.bat = {
      themes = {
        flexoki-dark = {
          src = pkgs.writeTextDir "flexoki-dark.tmTheme" (mkTmTheme "flexoki-dark" p.dark.base16);
          file = "flexoki-dark.tmTheme";
        };
        flexoki-light = {
          src = pkgs.writeTextDir "flexoki-light.tmTheme" (mkTmTheme "flexoki-light" p.light.base16);
          file = "flexoki-light.tmTheme";
        };
      };
      config =
        { theme = if isDarwin then "auto:system" else "flexoki-dark"; }
        // lib.optionalAttrs isDarwin {
          "theme-dark" = "flexoki-dark";
          "theme-light" = "flexoki-light";
        };
    };

    # fish: install both themes and re-select on login. macOS picks by appearance
    # (a new shell after a light/dark flip repaints); Linux pins dark.
    xdg.configFile."fish/themes/Flexoki Dark.theme".source = fishDark;
    xdg.configFile."fish/themes/Flexoki Light.theme".source = fishLight;
    programs.fish.interactiveShellInit = lib.mkAfter (
      if isDarwin then
        ''
          if test (defaults read -g AppleInterfaceStyle 2>/dev/null) = Dark
              fish_config theme choose "Flexoki Dark"
          else
              fish_config theme choose "Flexoki Light"
          end
        ''
      else
        ''fish_config theme choose "Flexoki Dark"''
    );
  }

  # On macOS fzf and lazygit are left un-themed so they inherit ghostty's Flexoki
  # ANSI palette and switch with the system appearance. On Linux the terminal is
  # DMS/matugen-driven, so pin them to a static Flexoki dark palette — the
  # fallback slot catppuccin used to fill.
  (lib.mkIf (!isDarwin) {
    programs.fzf.colors = {
      "fg" = "#878580";
      "bg" = "#100F0F";
      "hl" = "#CECDC3";
      "fg+" = "#878580";
      "bg+" = "#1C1B1A";
      "hl+" = "#CECDC3";
      "border" = "#AF3029";
      "header" = "#CECDC3";
      "gutter" = "#100F0F";
      "spinner" = "#24837B";
      "info" = "#24837B";
      "separator" = "#1C1B1A";
      "pointer" = "#AD8301";
      "marker" = "#AF3029";
      "prompt" = "#AD8301";
    };

    programs.lazygit.settings.gui.theme = {
      activeBorderColor = [
        "#4385be"
        "bold"
      ];
      inactiveBorderColor = [ "#575653" ];
      searchingActiveBorderColor = [
        "#d0a215"
        "bold"
      ];
      optionsTextColor = [ "#4385be" ];
      selectedLineBgColor = [ "#282726" ];
      cherryPickedCommitBgColor = [ "#282726" ];
      cherryPickedCommitFgColor = [ "#3aa99f" ];
      unstagedChangesColor = [ "#d14d41" ];
      defaultFgColor = [ "#cecdc3" ];
    };
  })
]
