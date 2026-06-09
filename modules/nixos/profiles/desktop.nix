{ config, lib, ... }:
let
  cfg = config.kyan.profiles.desktop;
in
{
  options.kyan.profiles.desktop.enable = lib.mkEnableOption "Hyprland desktop profile";

  config = lib.mkIf cfg.enable {
    # The Hyprland session, portals and login manager are wired in
    # ../mixins/hyprland.nix; this flag gates them on per-host.
    kyan.desktop.enable = true;
  };
}
