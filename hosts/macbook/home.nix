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

  # Host-specific settings only
  # programs.oh-my-posh = {
  #   useTheme = "catppuccin_mocha";
  # };
}
