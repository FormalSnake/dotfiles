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
    
    # GUI applications
    firefox
    brave
  ];

  # Enable X11 and Wayland specific configurations if needed
  programs.oh-my-posh.enableNushellIntegration = true;
  
  # Import any NixOS specific program configurations here
  imports = [];
}