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

  # Add sudo to path
  home.sessionPath = [
    "/run/wrappers/bin"
  ];

  # NixOS-specific packages only
  home.packages = with pkgs; [
    # Linux-specific dev utilities
    github-desktop

    # Terminal emulator (Linux package only due to macOS signing)
    ghostty

    # Sway utilities
    nerd-fonts.geist-mono

    # Media
    spotify

    # Internet
    brave
  ];

  imports = [
    ../../../modules/home-manager/programs/sway
    ../../../modules/home-manager/programs/waybar
  ];
}
