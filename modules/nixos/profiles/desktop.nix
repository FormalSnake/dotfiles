{ config, lib, ... }:
let
  cfg = config.kyan.profiles.desktop;
in
{
  options.kyan.profiles.desktop.enable = lib.mkEnableOption "Hyprland desktop profile";

  config = lib.mkIf cfg.enable {
    # The Hyprland session, portals and login manager are wired in
    # ../mixins/hyprland.nix; this flag gates them on per-host.
    kyan.desktop.enable = true;

    # Shared Flatpak base (mixins/flatpak.nix): every desktop host gets the
    # flatpak service + flathub remote, so user-level Flatpaks work everywhere.
    # GPU-bound Flatpaks don't belong in shared config, declare those per-host.
    kyan.flatpak.enable = lib.mkDefault true;
  };
}
