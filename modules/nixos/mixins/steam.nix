{ config, lib, ... }:
let
  cfg = config.kyan.steam;
in
{
  options.kyan.steam.enable =
    lib.mkEnableOption "Steam client (workshop downloads only, gaming lives on Windows)";

  # Bare Steam client, not autostarted. No firewall opens, no
  # gamescope/gamemode/Proton extras: that stack was removed when gaming moved
  # to Windows.
  config = lib.mkIf cfg.enable {
    programs.steam.enable = true;
  };
}
