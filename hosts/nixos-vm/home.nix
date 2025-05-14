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

  # Host-specific packages for the VM
  home.packages = with pkgs; [
    firefox
    gnome-tweaks
  ];

  # VM-specific settings
  programs.oh-my-posh = {
    useTheme = "huvix";
  };

  # Explicitly enable ZSH for NixOS
  programs.zsh.enable = true;

  # Import Hyprland configuration
  imports = [
    ../../modules/programs/hyprland.nix
  ];
}
