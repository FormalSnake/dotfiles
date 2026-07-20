{ config, ... }:
{
  # qt6ct / qt5ct config: select the Fusion style and DMS's generated colour
  # scheme. The colors/matugen.conf files are written at runtime by DMS's
  # builtin `qt6ct`/`qt5ct` matugen templates; these .conf files just tell
  # qt{5,6}ct to use them. Managed declaratively (read-only) — don't hand-edit
  # via the qt6ct GUI.
  #
  # The Qt platform theme itself (QT_QPA_PLATFORMTHEME=qt6ct) is exported from
  # programs.niri.settings.environment in niri.nix so it reaches every niri-spawned Qt app; this
  # file only owns the qt{5,6}ct.conf colour/style selection. DMS's builtin qt
  # templates (AvengeMedia/DankMaterialShell core/internal/matugen/matugen.go
  # templateRegistry — no user template needed) write
  # ~/.config/qt{5,6}ct/colors/matugen.conf whenever qt{5,6}ct is detected on
  # PATH, and the qt6ct.conf below points at it with a Fusion style (Fusion
  # honours the custom palette). Qt apps pick up the colours at launch — no
  # live recolour (Qt has no palette hot-reload).
  xdg.configFile."qt6ct/qt6ct.conf".text = ''
    [Appearance]
    style=Fusion
    custom_palette=true
    color_scheme_path=${config.home.homeDirectory}/.config/qt6ct/colors/matugen.conf
    icon_theme=Colloid-Dark
    standard_dialogs=default
  '';
  xdg.configFile."qt5ct/qt5ct.conf".text = ''
    [Appearance]
    style=Fusion
    custom_palette=true
    color_scheme_path=${config.home.homeDirectory}/.config/qt5ct/colors/matugen.conf
    icon_theme=Colloid-Dark
    standard_dialogs=default
  '';
}
