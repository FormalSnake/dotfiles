{ config, lib, ... }:
let
  cfg = config.kyan.sober;
in
{
  options.kyan.sober.enable =
    lib.mkEnableOption "Sober (Roblox client for Linux, installed via Flatpak)";

  # Sober is only distributed as a Flatpak (org.vinegarhq.Sober on Flathub) —
  # there is no nixpkgs package. nix-flatpak installs/updates it declaratively
  # on each rebuild. The nix-flatpak NixOS module is imported in ../default.nix.
  config = lib.mkIf cfg.enable {
    services.flatpak = {
      enable = true;

      remotes = lib.mkOptionDefault [
        {
          name = "flathub";
          location = "https://flathub.org/repo/flathub.flatpakrepo";
        }
      ];

      packages = [ "org.vinegarhq.Sober" ];
    };
  };
}
