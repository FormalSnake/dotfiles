{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.gaming;

  # PRIME render-offload env + the launcher-wrapping helper are defined once in
  # ../mixins/nvidia.nix and exposed via an overlay (pkgs.nvidiaOffloadEnv /
  # pkgs.gpuOffloadWrap). See that file for the rationale (push each game
  # launcher onto the dGPU so games use the RTX 5070 with no per-title config).
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
      # Big Picture / "console mode" session: render gamescope itself and the
      # Steam client on the dGPU too, so the tenfoot UI isn't stuck on the iGPU.
      gamescopeSession.env = pkgs.nvidiaOffloadEnv;
      protontricks.enable = true;
      # Proton-GE shows up in Steam's compatibility-tool dropdown.
      extraCompatPackages = [ pkgs.proton-ge-bin ];
      # Desktop-mode client + every game it spawns default to the RTX 5070.
      # The steam module merges its own extraEnv (compat-tool paths, …) on top
      # of this, so nothing is clobbered.
      package = pkgs.steam.override { extraEnv = pkgs.nvidiaOffloadEnv; };
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

      # Launchers (Epic / GOG / non-Steam). Wrapped so games launched through
      # them render on the dGPU (PRIME offload) — see ../mixins/nvidia.nix.
      (gpuOffloadWrap lutris)
      (gpuOffloadWrap heroic)

      # Comms / streaming.
      equibop # Discord client (Vesktop fork)
      obs-studio
    ];
  };
}
