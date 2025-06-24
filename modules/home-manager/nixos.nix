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

    # GNOME utilities
    gnome-tweaks
    dconf-editor
  ];
}

