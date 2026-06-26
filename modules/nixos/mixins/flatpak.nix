{ config, lib, ... }:
let
  cfg = config.kyan.flatpak;
in
{
  options.kyan.flatpak.enable =
    lib.mkEnableOption "declarative Flatpak management (nix-flatpak)";

  # Base Flatpak service: turns on nix-flatpak, wires the Flathub remote, and
  # refreshes installed Flatpaks on a daily timer. Individual apps add themselves
  # to services.flatpak.packages and pull this in via kyan.flatpak.enable (e.g.
  # ./sober.nix). The nix-flatpak NixOS module is imported in ../default.nix.
  config = lib.mkIf cfg.enable {
    services.flatpak = {
      enable = true;

      # Flatpak apps such as Sober track fast-moving upstreams (Roblox) — refresh
      # installed Flatpaks on a daily timer so they stay current without manual
      # `flatpak update` / rebuilds.
      update.auto = {
        enable = true;
        onCalendar = "daily";
      };

      remotes = lib.mkOptionDefault [
        {
          name = "flathub";
          location = "https://flathub.org/repo/flathub.flatpakrepo";
        }
      ];
    };
  };
}
