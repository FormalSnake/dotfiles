{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  # Configure home directory and username specific to this host
  home.username = "kyandesutter";
  home.homeDirectory = "/Users/kyandesutter";

  # macOS-specific packages only
  home.packages = with pkgs; [
    # macOS-specific utilities
    # ice-bar
    # the-unarchiver
    # whatsapp-for-mac
    # raycast
    # appcleaner
    # terminal-notifier
  ];

  # Import macOS-specific program configurations
  imports = [
    # Aerospace
    ../../../modules/home-manager/programs/aerospace
    # Sketchybar
    # ../../../modules/home-manager/programs/sketchybar
  ];
}
