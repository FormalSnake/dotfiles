{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  # NixOS-specific packages only
  home.packages = with pkgs; [
    # Linux-specific terminal utilities
    neofetch

    # Linux-specific dev utilities
    github-desktop

    # Terminal emulator (Linux package only due to macOS signing)
    ghostty

    # Hyprland utilities (Linux-specific)
    waybar
    swww
    dunst
    rofi-wayland
    wl-clipboard
    grim
    slurp
    wofi
  ];

  # Import NixOS-specific program configurations
  imports = [
    ../programs/hyprland.nix
  ];
}

