{ config, lib, ... }:
let
  cfg = config.kyan.mimick;
in
{
  options.kyan.mimick.enable =
    lib.mkEnableOption "Mimick (unofficial Immich desktop client, installed via Flatpak)";

  # Mimick is a native GTK4/Libadwaita Immich client distributed only as a
  # Flatpak (dev.nicx.mimick on Flathub) — there is no nixpkgs package. It rides
  # on the declarative Flatpak base in ./flatpak.nix (enabled below), which
  # nix-flatpak installs/updates on each rebuild.
  config = lib.mkIf cfg.enable {
    kyan.flatpak.enable = true;

    services.flatpak.packages = [ "dev.nicx.mimick" ];
  };
}
