{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  # Configure home directory and username specific to this host
  home.username = "kyandesutter";
  home.homeDirectory = "/home/kyandesutter";

  # NixOS-specific packages only
  home.packages = with pkgs; [
    # Terminal emulator (Linux package only due to macOS signing)
    ghostty

    # GNOME utilities
    gnome-tweaks
    dconf-editor

    # Media
    spotify
  ];
}
