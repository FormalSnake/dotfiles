{ config, lib, ... }:
let
  cfg = config.kyan.steam;
in
{
  options.kyan.steam.enable =
    lib.mkEnableOption "Steam client (Wallpaper Engine workshop downloads only — gaming lives on Windows)";

  # Bare Steam client, kept solely for subscribing/downloading Wallpaper Engine
  # workshop scenes (users/kyandesutter/mixins/wallpaper-engine.nix reads the
  # workshop content dir on disk). Not autostarted; launch it manually when a
  # new scene is needed. No firewall opens, no gamescope/gamemode/Proton extras
  # — that stack was removed when gaming moved to Windows.
  config = lib.mkIf cfg.enable {
    programs.steam.enable = true;
  };
}
