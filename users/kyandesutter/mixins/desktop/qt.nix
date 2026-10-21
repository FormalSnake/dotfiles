{ config, pkgs, ... }:
let
  # Style::polish(QPalette &) overwrites the application palette with
  # adwaita-qt's built-in light one, so the qtct palette never shows. Leaving
  # the palette alone keeps the widget shapes and takes the matugen colours.
  keepPalette = p: p.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/style/adwaitastyle.cpp \
        --replace-fail "palette = Colors::palette(_variant);" ""
    '';
  });

  qtctConf = qt: ''
    [Appearance]
    style=Adwaita
    custom_palette=true
    color_scheme_path=${config.home.homeDirectory}/.config/${qt}/colors/matugen.conf
    icon_theme=Colloid-Dark
    standard_dialogs=default

    [Fonts]
    general="Adwaita Sans,11,-1,5,50,0,0,0,0,0"
    fixed="GeistMono Nerd Font,11,-1,5,50,0,0,0,0,0"
  '';
in
{
  # adwaita-qt draws the libadwaita widget shapes, so Qt apps match the
  # adw-gtk3 GTK side.
  home.packages = [ (keepPalette pkgs.adwaita-qt) (keepPalette pkgs.adwaita-qt6) ];

  # qt6ct / qt5ct config: select the Adwaita style and the shell's generated
  # colour scheme. The colors/matugen.conf files are written at runtime by the
  # active shell's matugen templates (DMS's builtin `qt6ct`/`qt5ct` ones, or
  # FormalShell's qtct-colors.conf.tmpl on formalshell hosts (same output
  # path)). These .conf files just tell qt{5,6}ct to use them. Managed
  # declaratively (read-only), don't hand-edit via the qt6ct GUI.
  #
  # The Qt platform theme itself (QT_QPA_PLATFORMTHEME=qt6ct) is exported from
  # both Hyprland's own `hl.env` block and ~/.config/uwsm/env (hyprland.nix), so
  # it reaches Hyprland-spawned apps and systemd user services alike; this
  # file only owns the qt{5,6}ct.conf colour/style selection. Qt apps pick up
  # the colours at launch: no live recolour (Qt has no palette hot-reload).
  # [Fonts] pins Adwaita Sans/GeistMono so Qt apps match the GTK side instead of taking
  # whatever QGuiApplication::font() resolves to. Both qt5ct and qt6ct read
  # these through QFont::fromString on a plain string, so the value is the
  # Qt5-style 10-field spec (family,pointSize,pixelSize,styleHint,weight,style,
  # underline,strikeOut,fixedPitch,rawMode); Qt6 maps the legacy weight 50 onto
  # its own 400. The quotes are load-bearing: QSettings splits an unquoted
  # comma-separated value into a QStringList and .toString() on that is empty.
  xdg.configFile."qt6ct/qt6ct.conf".text = qtctConf "qt6ct";
  xdg.configFile."qt5ct/qt5ct.conf".text = qtctConf "qt5ct";
}
