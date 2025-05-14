{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  # Additional packages specific to macOS
  home.packages = with pkgs; [
    # macOS specific developer tools
    aider-chat
    claude-code
    pyenv

    # macOS specific utilities
    ice-bar
    mousecape
    the-unarchiver

    # Applications
    firefox
    spotify-player
    zed-editor
  ];

  # Enable macOS specific programs
  programs.oh-my-posh.enableZshIntegration = true;

  # Import macOS specific configurations
  imports = [
    ../programs/ghostty.nix
    ../programs/btop.nix
    ../programs/fastfetch.nix
  ];
}
