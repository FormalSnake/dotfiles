{ config, lib, ... }:
let
  cfg = config.kyan.flatpak;
in
{
  options.kyan.flatpak.enable =
    lib.mkEnableOption "declarative Flatpak management (nix-flatpak)";

  # Base Flatpak service: turns on nix-flatpak, wires the Flathub remote, and
  # refreshes installed Flatpaks on a daily timer. Enabled for every desktop
  # host by ../profiles/desktop.nix; apps add themselves to
  # services.flatpak.packages (system) or ride on it as user Flatpaks (Spotify,
  # users/kyandesutter/mixins/spicetify.nix). The nix-flatpak NixOS module is
  # imported in ../default.nix.
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
