{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  # macOS-specific packages only
  home.packages = with pkgs; [
    # macOS-specific developer tools
    aider-chat
    claude-code
    pyenv
    nixd
    devenv
    chafa
    repomix

    # macOS-specific utilities
    ice-bar
    mousecape
    the-unarchiver

    # Applications
    zed-editor
  ];

  # Import macOS-specific program configurations
  imports = [
    # Aerospace
    ../programs/aerospace.nix
  ];
}

