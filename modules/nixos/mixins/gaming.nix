{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.gaming;
in
{
  options.kyan.gaming.enable = lib.mkEnableOption "gaming stack (Steam, gamescope, gamemode, launchers)";

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      gamescopeSession.enable = true;
      protontricks.enable = true;
      # Proton-GE shows up in Steam's compatibility-tool dropdown.
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };

    programs.gamescope = {
      enable = true;
      capSysNice = true; # lets gamescope set nice/rtprio
    };

    programs.gamemode = {
      enable = true;
      settings.general = {
        renice = 10;
        # gamemode flips the CPU governor to performance for the running game.
        desiredgov = "performance";
      };
    };

    environment.systemPackages = with pkgs; [
      # Overlays / post-processing (enable per-game via env vars).
      mangohud
      vkbasalt
      protonup-qt # manage extra Proton-GE versions

      # Launchers (Epic / GOG / non-Steam).
      lutris
      heroic

      # Comms / streaming.
      vesktop # Discord client
      obs-studio
    ];
  };
}
