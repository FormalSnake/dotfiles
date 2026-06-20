{ config, ... }:
{
  # qt6ct / qt5ct config: select the Fusion style and Noctalia's generated colour
  # scheme. The colors/noctalia.conf files are written at runtime by Noctalia's
  # `qt` template; these .conf files just tell qt{5,6}ct to use them. Managed
  # declaratively (read-only) — don't hand-edit via the qt6ct GUI.
  #
  # The Qt platform theme itself (QT_QPA_PLATFORMTHEME=qt6ct) is exported from
  # uwsm/env in hyprland.nix so it reaches every Hyprland-spawned Qt app; this
  # file only owns the qt{5,6}ct.conf colour/style selection. Noctalia's builtin
  # `qt` template (see noctalia.nix) writes ~/.config/qt{5,6}ct/colors/noctalia.conf,
  # and the qt6ct.conf below points at it with a Fusion style (Fusion honours the
  # custom palette). Qt apps pick up the colours at launch — no live recolour (Qt
  # has no palette hot-reload).
  xdg.configFile."qt6ct/qt6ct.conf".text = ''
    [Appearance]
    style=Fusion
    custom_palette=true
    color_scheme_path=${config.home.homeDirectory}/.config/qt6ct/colors/noctalia.conf
    icon_theme=Papirus-Dark
    standard_dialogs=default
  '';
  xdg.configFile."qt5ct/qt5ct.conf".text = ''
    [Appearance]
    style=Fusion
    custom_palette=true
    color_scheme_path=${config.home.homeDirectory}/.config/qt5ct/colors/noctalia.conf
    icon_theme=Papirus-Dark
    standard_dialogs=default
  '';
}
