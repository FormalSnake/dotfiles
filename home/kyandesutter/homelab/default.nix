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
    # Linux-specific dev utilities
    github-desktop

    # Terminal emulator (Linux package only due to macOS signing)
    ghostty

    # KDE utilities
    kdePackages.kate

    # Media
    spotify

    # Internet
    brave
  ];
}
