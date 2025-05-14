{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  # NixOS specific packages
  home.packages = with pkgs; [
    # Terminal utilities
    btop
    neofetch

    # Development
    nodejs
    bun
    cargo
    rustc
    go
    zig

    # Terminal emulator for Hyprland
    kitty

    # GUI applications
    firefox
    brave
  ];

  # Import any NixOS specific program configurations here
  imports = [];
}

