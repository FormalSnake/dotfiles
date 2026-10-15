{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.gaming;
  epic-games-launcher = pkgs.callPackage ./epic-games-launcher.nix { };
in
{
  options.kyan.gaming.enable = lib.mkEnableOption "Steam, Heroic (Epic library) and the Proton tooling around them";

  # Fortnite is not covered here and cannot be on NixOS as Epic specified EAC
  # Linux v2 (2026-10-14): it requires a kernel and every module signed with a
  # well-known distro key (Ubuntu, Fedora, Debian, openSUSE, Universal Blue).
  # A NixOS kernel and the nixpkgs NVIDIA module are unsigned, and lanzaboote
  # only signs with self-enrolled keys. Fortnite stays on the Windows side.
  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      protontricks.enable = true;
      # GE-Proton shows up in Steam's per-game compatibility dropdown.
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };

    # Steam picks gamemode up per game with `gamemoderun %command%`.
    programs.gamemode.enable = true;
    programs.gamescope.enable = true;

    environment.systemPackages = [
      epic-games-launcher
      # Fallback Epic client (Legendary underneath) while the official one is
      # in preview.
      pkgs.heroic
      pkgs.mangohud
    ];
  };
}
