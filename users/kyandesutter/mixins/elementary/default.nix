{ config, lib, pkgs, osConfig ? { }, ... }:
let
  useFormalshell = (((osConfig.kyan or { }).desktop or { }).shell or "dms") == "formalshell";

  theme = pkgs.callPackage ./gtk-theme.nix { };
  kvantum = pkgs.callPackage ./kvantum-theme.nix { };
  kvantumDir = "${config.xdg.configHome}/Kvantum/${kvantum.themeName}";

  # Every role recolor.py maps a literal to, in either mode. Both modes are
  # rendered into the same file with matugen's .light/.dark views, because
  # the stylesheet names them per mode: the dark window is a
  # surface_container_low where the light one is surface.
  roles = [
    "surface"
    "surface_dim"
    "surface_container_lowest"
    "surface_container_low"
    "surface_container"
    "surface_container_high"
    "surface_container_highest"
    "inverse_surface"
    "outline_variant"
    "on_surface"
    "on_surface_variant"
  ];
  defines = lib.concatMapStrings
    (mode: lib.concatMapStrings (role: "@define-color m3_${mode}_${role} {{colors.${role}.${mode}.hex}};\n") roles)
    [ "light" "dark" ];

  # GTK3 apps load the stylesheet as their theme (FormalShell sets the name),
  # so their file only carries the palette.
  gtk3Template = pkgs.writeText "elementary-gtk3-colors.css.tmpl" defines;

  # libadwaita ignores gtk-theme and always draws its own stylesheet, so GTK4
  # apps get elementary's through the user gtk.css instead, at the variant
  # matching the mode. The accent is restated after the import: the
  # stylesheet defines accent_color itself, and within one provider the later
  # definition wins over formalshell-colors.css.
  gtk4Template = pkgs.writeText "elementary-gtk4-colors.css.tmpl" ''
    @import url("file://${theme}/share/themes/${theme.themeName "{{mode}}"}/gtk-4.0/gtk.css");
    @define-color accent_color {{colors.primary.default.hex}};
    ${defines}'';
in
lib.mkIf useFormalshell {
  home.packages = [
    theme
    pkgs.kdePackages.qtstyleplugin-kvantum
    pkgs.libsForQt5.qtstyleplugin-kvantum
  ];

  # Merged into FormalShell's own matugen run on every wallpaper and mode change.
  xdg.configFile."formalshell/matugen.d/elementary-gtk.toml".text = ''
    [templates.elementary-gtk3]
    input_path = "${gtk3Template}"
    output_path = "${config.xdg.configHome}/gtk-3.0/elementary-colors.css"

    [templates.elementary-gtk4]
    input_path = "${gtk4Template}"
    output_path = "${config.xdg.configHome}/gtk-4.0/elementary-colors.css"
  '';

  # Qt apps draw the same material through Kvantum (mixins/qt.nix selects the
  # style). Qt reads the theme at launch, so a running app keeps its colours.
  xdg.configFile."formalshell/matugen.d/elementary-kvantum.toml".text = ''
    [templates.elementary-kvantum-svg]
    input_path = "${kvantum}/theme.svg.tmpl"
    output_path = "${kvantumDir}/${kvantum.themeName}.svg"

    [templates.elementary-kvantum-config]
    input_path = "${kvantum}/theme.kvconfig.tmpl"
    output_path = "${kvantumDir}/${kvantum.themeName}.kvconfig"
  '';
  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=${kvantum.themeName}
  '';

  # After formalshell-colors.css, so these definitions win where both name a colour.
  gtk.gtk3.extraCss = lib.mkAfter ''@import url("elementary-colors.css");'';
  gtk.gtk4.extraCss = lib.mkAfter ''@import url("elementary-colors.css");'';

  programs.formalshell.settings.gtk = {
    theme = theme.themeName "light";
    themeDark = theme.themeName "dark";
  };

  # No buttons on GTK headerbars. Hyprland answers every decoration request
  # with server-side, so Qt draws none of its own, and GTK matches that.
  dconf.settings."org/gnome/desktop/wm/preferences".button-layout = ":";

  # The shell's own chrome follows the desktop: elementary's relief on every
  # control and a shadow under every card (FormalShell's pantheon preset).
  programs.formalshell.settings.theme.preset = "pantheon";
}
