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

    # Hyprland utilities
    waybar
    swww
    dunst
    rofi-wayland
    wl-clipboard
    grim
    slurp

    # GUI applications
    firefox
    brave
  ];

  # Import any NixOS specific program configurations here
  imports = [];
}

