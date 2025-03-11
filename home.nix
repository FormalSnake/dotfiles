{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = _: true;
    };
    overlays = [
      (final: prev: {
        vimPlugins =
          prev.vimPlugins
          // {
            own-auto-dark-mode = prev.vimUtils.buildVimPlugin {
              name = "auto-dark-mode.nvim";
              src = inputs.plugin-auto-dark-mode;
            };
          };
      })
    ];
  };

  home.username = "kyandesutter";
  home.homeDirectory = "/Users/kyandesutter";

  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  home.packages = [
    pkgs.aider-chat # AI-assisted code editing tool
    pkgs.raycast # Launcher and productivity tool
    pkgs.ice-bar # Status bar utility
    pkgs.aerospace # Aerospace-related tools
    pkgs.mousecape # Custom cursors for macOS
    pkgs.the-unarchiver # Archive extraction utility
    pkgs.google-chrome # Web browser
    pkgs.xcode-install
  ];

  catppuccin.flavor = "mocha";
  catppuccin.enable = true;

  programs.git = {
    enable = true;
  };

  imports = [
    ./programs/zsh.nix
    ./programs/neovim.nix
    ./programs/tmux.nix
    ./programs/aerospace.nix
    ./programs/ghostty.nix
    ./programs/btop.nix
  ];
}
