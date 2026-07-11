{ config, lib, ... }:
let
  cfg = config.kyan.profiles.desktop;
in
{
  options.kyan.profiles.desktop.enable = lib.mkEnableOption "niri desktop profile";

  config = lib.mkIf cfg.enable {
    # The niri session, portals and login manager are wired in
    # ../mixins/niri.nix; this flag gates them on per-host.
    kyan.desktop.enable = true;
  };
}
