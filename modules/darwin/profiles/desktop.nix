{ config, lib, ... }:
let
  cfg = config.kyan.profiles.desktop;
in
{
  options.kyan.profiles.desktop.enable = lib.mkEnableOption "desktop profile";

  config = lib.mkIf cfg.enable {
    # Placeholder — populated in later phases (dock pins, login items, etc.)
  };
}
