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

  # Host-specific settings only
  # programs.oh-my-posh = {
  #   useTheme = "huvix";
  # };

  # Explicitly enable ZSH for NixOS
  programs.zsh.enable = true;
}
