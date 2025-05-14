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
    vscode
    gnome.gnome-tweaks
  ];
  
  # VM-specific settings
  programs.oh-my-posh = {
    useTheme = "huvix";
  };
  
  # GNOME-specific settings
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      enable-hot-corners = false;
    };
    "org/gnome/desktop/wm/preferences" = {
      button-layout = "appmenu:minimize,maximize,close";
    };
  };
}