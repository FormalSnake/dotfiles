{ config, lib, ... }:
let
  cfg = config.kyan.profiles.gaming;
in
{
  options.kyan.profiles.gaming.enable = lib.mkEnableOption "gaming profile (Steam, gamescope, gamemode)";

  config = lib.mkIf cfg.enable {
    # The actual gaming stack is wired in ../mixins/gaming.nix; this flag gates it.
    kyan.gaming.enable = true;
  };
}
